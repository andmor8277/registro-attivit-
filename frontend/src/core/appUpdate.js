// Update checker per la build Android (APK distribuita fuori dal Play Store).
// Il web non passa di qui: ci pensa versionCheck.js a ricaricare la pagina da solo.
// Modello allineato a ListaSpesa/src/services/updateService.ts: GitHub Releases come
// sorgente primaria, version.json raw come fallback (le API GitHub hanno il limite di
// 60 richieste/ora per IP, il fallback no).

import { Capacitor } from '@capacitor/core'
import { App as CapApp } from '@capacitor/app'
import { Browser } from '@capacitor/browser'

export const GITHUB_REPO_OWNER = 'andmor8277'
export const GITHUB_REPO_NAME = 'thof-releases'

const SKIPPED_VERSION_STORAGE_KEY = 'thof_skipped_update_version_v1'
const CHECK_TIMEOUT_MS = 7000
const CHECK_INTERVAL_MS = 30 * 60 * 1000

const DEFAULT_APK_URL = `https://github.com/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}/releases/latest/download/THOF.apk`
const DEFAULT_RELEASE_PAGE_URL = `https://github.com/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}/releases/latest`
const DEFAULT_MANIFEST_URL = `https://raw.githubusercontent.com/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}/main/version.json`

const RELEASE_NOTIES_FALLBACK = '• Miglioramenti generali e di stabilità'

function isNative() {
  return typeof Capacitor !== 'undefined' && Capacitor.isNativePlatform()
}

/**
 * Normalizza una versione togliendo prefissi tipo "v" o "release-" e il suffisso -beta.
 */
export function normalizeVersion(rawVersion) {
  return String(rawVersion ?? '')
    .trim()
    .replace(/^[vV]/, '')
    .replace(/^release[-_]?/i, '')
    .split('-')[0]
    .trim()
}

/**
 * Confronto semantico: true se remoteVersion è più alta di localVersion.
 */
export function isNewerVersion(localVersion, remoteVersion) {
  const cleanLocal = normalizeVersion(localVersion)
  const cleanRemote = normalizeVersion(remoteVersion)
  if (!cleanRemote || cleanLocal === cleanRemote) return false

  const localParts = cleanLocal.split('.').map((n) => parseInt(n, 10) || 0)
  const remoteParts = cleanRemote.split('.').map((n) => parseInt(n, 10) || 0)
  const maxLen = Math.max(localParts.length, remoteParts.length, 3)

  for (let i = 0; i < maxLen; i++) {
    const l = localParts[i] ?? 0
    const r = remoteParts[i] ?? 0
    if (r > l) return true
    if (r < l) return false
  }
  return false
}

/**
 * Decide se la release remota è da installare.
 * Il versionName (tag) comanda; a parità di tag decide il versionCode, che in THOF è il
 * numero di commit: serve per i rebuild sotto lo stesso tag, altrimenti l'utente non
 * verrebbe mai avvisato di una build più recente della stessa versione.
 */
export function hasNewerRelease(localVersion, localBuild, remoteVersion, remoteBuild) {
  if (isNewerVersion(localVersion, remoteVersion)) return true
  // "Stessa versione" va deciso semanticamente: se confrontassi le stringhe normalizzate,
  // "7.4" e "7.4.0" sembrerebbero due versioni diverse e il confronto per build non
  // partirebbe mai, lasciando l'utente su una build vecchia sotto lo stesso tag.
  if (isNewerVersion(remoteVersion, localVersion)) return false
  const lb = parseInt(localBuild, 10) || 0
  const rb = parseInt(remoteBuild, 10) || 0
  return rb > lb
}

export async function skipAppUpdateVersion(version) {
  try {
    localStorage.setItem(SKIPPED_VERSION_STORAGE_KEY, normalizeVersion(version))
  } catch (e) {
    console.warn('[THOF] Errore salvataggio versione ignorata:', e)
  }
}

export function getSkippedAppUpdateVersion() {
  try {
    return localStorage.getItem(SKIPPED_VERSION_STORAGE_KEY)
  } catch {
    return null
  }
}

async function fetchJsonWithTimeout(url, headers) {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), CHECK_TIMEOUT_MS)
  try {
    const res = await fetch(url, { headers, signal: controller.signal, cache: 'no-store' })
    if (!res.ok) return null
    return await res.json()
  } catch {
    return null
  } finally {
    clearTimeout(timer)
  }
}

function pickApkAsset(assets) {
  if (!Array.isArray(assets)) return null
  return (
    assets.find(
      (a) =>
        typeof a?.name === 'string' &&
        a.name.toLowerCase().endsWith('.apk') &&
        typeof a?.browser_download_url === 'string'
    ) ||
    assets.find(
      (a) =>
        a?.content_type === 'application/vnd.android.package-archive' &&
        typeof a?.browser_download_url === 'string'
    ) ||
    null
  )
}

/**
 * Note di rilascio pronte da mostrare: toglie i commenti HTML e, se non resta nulla,
 * usa il testo di default. Il marcatore thof-versionCode vive nel body come commento
 * (invisibile sulla pagina GitHub), ma qui il body viene reso come testo e mostrerebbe
 * una riga `<!-- ... -->` dentro l'avviso.
 */
function sanitizeNotes(rawBody) {
  const clean = String(rawBody ?? '').replace(/<!--[\s\S]*?-->/g, '').trim()
  return clean.length > 0 ? clean : RELEASE_NOTIES_FALLBACK
}

function buildInfoFromRelease(releaseData, installed) {
  const tagName = String(releaseData.tag_name)
  const latestVersion = normalizeVersion(tagName)
  const asset = pickApkAsset(releaseData.assets)

  // La Release API di GitHub non espone nessun versionCode. Senza, due APK diversi
  // sotto lo stesso tag sarebbero indistinguibili e la più recente non verrebbe mai
  // proposta. publish_android_apk.sh lo scrive come commento HTML nel body: invisibile
  // sulla pagina renderizzata, leggibile dall'API.
  const bodyBuild =
    typeof releaseData.body === 'string' ? (releaseData.body.match(/thof-versionCode:\s*(\d+)/i) || [])[1] : undefined
  const remoteBuild = releaseData.versionCode ?? bodyBuild

  return {
    hasUpdate: hasNewerRelease(installed.version, installed.build, latestVersion, remoteBuild),
    currentVersion: installed.version,
    currentBuild: installed.build,
    latestVersion,
    latestBuild: remoteBuild ? String(remoteBuild) : null,
    tagName,
    releaseName: releaseData.name ? String(releaseData.name) : `The Home of Football ${tagName}`,
    releaseNotes: sanitizeNotes(releaseData.body),
    publishedAt: releaseData.published_at ? String(releaseData.published_at) : undefined,
    apkDownloadUrl: asset?.browser_download_url || DEFAULT_APK_URL,
    apkSizeMb: typeof asset?.size === 'number' && asset.size > 0 ? (asset.size / 1048576).toFixed(1) : undefined,
    releasePageUrl: typeof releaseData.html_url === 'string' ? releaseData.html_url : DEFAULT_RELEASE_PAGE_URL,
  }
}

function buildInfoFromManifest(manifest, installed) {
  const latestVersion = normalizeVersion(String(manifest.version))
  return {
    hasUpdate: hasNewerRelease(installed.version, installed.build, latestVersion, manifest.versionCode),
    currentVersion: installed.version,
    currentBuild: installed.build,
    latestVersion,
    latestBuild: manifest.versionCode ? String(manifest.versionCode) : null,
    tagName: manifest.tagName ? String(manifest.tagName) : `v${latestVersion}`,
    releaseName: manifest.releaseName ? String(manifest.releaseName) : `The Home of Football v${latestVersion}`,
    releaseNotes: sanitizeNotes(manifest.releaseNotes),
    publishedAt: manifest.publishedAt ? String(manifest.publishedAt) : undefined,
    apkDownloadUrl: manifest.apkDownloadUrl ? String(manifest.apkDownloadUrl) : DEFAULT_APK_URL,
    apkSizeMb: manifest.apkSizeMb ? String(manifest.apkSizeMb) : undefined,
    releasePageUrl: manifest.releasePageUrl ? String(manifest.releasePageUrl) : DEFAULT_RELEASE_PAGE_URL,
  }
}

/**
 * Controlla se esiste un APK più recente dell'installato.
 * Restituisce null quando non c'è nulla da fare: non nativo, versione uguale o
 * inferiore, release già ignorata con "Non ora", oppure rete/API non raggiungibile.
 *
 * @param {{forceManualCheck?: boolean, allowWeb?: boolean}} options
 *   forceManualCheck ignora il "Non ora" (usato dal controllo manuale nelle impostazioni)
 *   allowWeb permette il controllo anche fuori da Capacitor (solo per verifiche in dev)
 */
export async function checkForAppUpdate(options = {}) {
  const forceManualCheck = options.forceManualCheck ?? false
  const allowWeb = options.allowWeb ?? false
  if (!isNative() && !allowWeb) return null

  let installed = { version: '0.0.0', build: '0' }
  if (isNative()) {
    try {
      const info = await CapApp.getInfo()
      installed = { version: info?.version || '0.0.0', build: info?.build || '0' }
    } catch {
      return null
    }
  } else {
    installed = {
      version: typeof __APP_VERSION__ !== 'undefined' ? String(__APP_VERSION__) : '0.0.0',
      build: '0',
    }
  }

  const headers = {
    Accept: 'application/vnd.github+json',
    'User-Agent': `THOF-Android/${installed.version}`,
  }

  // 1. Release stabile ufficiale
  let releaseData = await fetchJsonWithTimeout(
    `https://api.github.com/repos/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}/releases/latest`,
    headers
  )

  // 2. Fallback: ultima release, pre-release incluse
  if (!releaseData || !releaseData.tag_name) {
    const list = await fetchJsonWithTimeout(
      `https://api.github.com/repos/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}/releases?per_page=1`,
      headers
    )
    if (Array.isArray(list) && list.length > 0) releaseData = list[0]
  }

  let info = null
  if (releaseData && releaseData.tag_name) {
    info = buildInfoFromRelease(releaseData, installed)

    // Caso stretto: il tag remoto è uguale a quello installato e la release non porta
    // il versionCode (la Release API non ce l'ha, e il body potrebbe non averlo se la
    // release è vecchia). Senza il build number non possiamo accorgerci di una rebuild
    // ripubblicata sotto lo stesso tag: lo chiediamo al manifest, che è l'unico che lo
    // scrive. Si paga una richiesta in più solo qui, non nel caso normale.
    if (info && !info.hasUpdate && !info.latestBuild && !isNewerVersion(installed.version, info.latestVersion) &&
        !isNewerVersion(info.latestVersion, installed.version)) {
      const manifest = await fetchJsonWithTimeout(`${DEFAULT_MANIFEST_URL}?t=${Date.now()}`, {})
      if (manifest && manifest.versionCode && normalizeVersion(String(manifest.version)) === info.latestVersion) {
        info = buildInfoFromManifest(manifest, installed)
      }
    }
  } else {
    // 3. Fallback su version.json nel branch: non consuma il rate limit delle API
    const manifest = await fetchJsonWithTimeout(`${DEFAULT_MANIFEST_URL}?t=${Date.now()}`, {})
    if (manifest && manifest.version) info = buildInfoFromManifest(manifest, installed)
  }

  if (!info || !info.hasUpdate) return null

  if (!forceManualCheck) {
    const skipped = getSkippedAppUpdateVersion()
    if (skipped && skipped === info.latestVersion) return null
  }

  return info
}

/**
 * Apre il download dell'APK: browser di sistema su Android (gestisce lui download e
 * richiesta di "installa da origini sconosciute"), scheda nuova su web.
 */
export async function openAppUpdateDownload(updateInfo) {
  const targetUrl = updateInfo?.apkDownloadUrl || updateInfo?.releasePageUrl || DEFAULT_APK_URL
  if (isNative()) {
    try {
      await Browser.open({ url: targetUrl, showLoader: true })
      return
    } catch (e) {
      console.warn('[THOF] Browser.open fallito, provo la pagina release:', e)
      try {
        await Browser.open({ url: updateInfo?.releasePageUrl || DEFAULT_RELEASE_PAGE_URL })
        return
      } catch {
        /* cado nel fallback web qui sotto */
      }
    }
  }
  if (typeof window !== 'undefined') window.open(targetUrl, '_blank')
}

/**
 * Avvia i controlli: all'avvio, al ritorno in primo piano e ogni 30 minuti.
 * Sui telefoni l'app passa in background in continuazione, quindi il resume è il
 * momento più frequente e va tenuto leggero: una sola richiesta, con timeout corto.
 */
export function initAppUpdateChecker(onUpdateFound) {
  if (typeof window === 'undefined' || !isNative()) return null

  let isChecking = false
  let started = false
  let timer = null

  const run = () => {
    if (isChecking) return
    isChecking = true
    checkForAppUpdate()
      .then((info) => {
        if (info && typeof onUpdateFound === 'function') onUpdateFound(info)
      })
      .finally(() => {
        isChecking = false
      })
  }

  const onVisible = () => {
    if (document.visibilityState === 'visible') run()
  }

  const start = () => {
    if (started) return
    started = true
    run()
    timer = setInterval(run, CHECK_INTERVAL_MS)
  }

  // L'app in primo piano la prima volta: si parte subito, altrimenti si aspetta il resume
  const kickoff = setTimeout(start, 3000)
  document.addEventListener('visibilitychange', onVisible)

  return () => {
    clearTimeout(kickoff)
    if (timer) clearInterval(timer)
    document.removeEventListener('visibilitychange', onVisible)
  }
}
