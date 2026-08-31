import json
import os
import re
import unicodedata
from datetime import date, datetime

_DATA_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "comuni_cup.json")

with open(_DATA_FILE, encoding="utf-8") as _f:
    _CUP = json.load(_f)

MESE = {1: "A", 2: "B", 3: "C", 4: "D", 5: "E", 6: "H", 7: "L", 8: "M", 9: "P", 10: "R", 11: "S", 12: "T"}
VOWELS = set("AEIOU")

_ODD = {
    "0": 1, "1": 0, "2": 5, "3": 7, "4": 9, "5": 13, "6": 15, "7": 17, "8": 19, "9": 21,
    "A": 1, "B": 0, "C": 5, "D": 7, "E": 9, "F": 13, "G": 15, "H": 17, "I": 19, "J": 21,
    "K": 2, "L": 4, "M": 18, "N": 20, "O": 11, "P": 3, "Q": 6, "R": 8, "S": 12, "T": 14,
    "U": 16, "V": 10, "W": 22, "X": 25, "Y": 24, "Z": 23,
}


def _norm(s):
    s = unicodedata.normalize("NFD", s or "")
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = s.upper().strip()
    return " ".join(s.split())


def _consonants(name):
    return [c for c in name if c.isalpha() and c not in VOWELS]


def _vowels(name):
    return [c for c in name if c in VOWELS]


def _extract3_cognome(name):
    """3 chars from surname: first 3 consonants, then vowels, then X."""
    name = (name or "").upper()
    out = list(_consonants(name)[:3])
    for v in _vowels(name):
        if len(out) >= 3:
            break
        out.append(v)
    while len(out) < 3:
        out.append("X")
    return "".join(out[:3])


def _extract3_nome(name):
    """3 chars from first name: 1st/3rd/4th consonant if >3, else consonants+vowels, then X."""
    name = (name or "").upper()
    cons = _consonants(name)
    if len(cons) > 3:
        out = [cons[0], cons[2], cons[3]]
    else:
        out = list(cons)
        for v in _vowels(name):
            if len(out) >= 3:
                break
            out.append(v)
    while len(out) < 3:
        out.append("X")
    return "".join(out[:3])


def _cup_for(comune):
    if not comune:
        return None
    key = _norm(comune)
    if key in _CUP:
        return _CUP[key]
    stripped = re.sub(r"\s*\([A-Z]{2}\)\s*$", "", key)
    if stripped in _CUP:
        return _CUP[stripped]
    parts = key.split()
    if len(parts) > 1 and parts[0] in _CUP:
        return _CUP[parts[0]]
    return None


def _check_digit(cf15):
    total = 0
    for i, ch in enumerate(cf15):
        ch = ch.upper()
        if (i + 1) % 2 == 1:  # odd position
            total += _ODD[ch]
        else:  # even position
            total += int(ch) if ch.isdigit() else (ord(ch) - ord("A"))
    return "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[total % 26]


def genera_codice_fiscale(nome, cognome, data_nascita, sesso, comune_nato):
    """Genera il codice fiscale italiano (16 caratteri).

    nome, cognome: str
    data_nascita: date/datetime o stringa 'YYYY-MM-DD'
    sesso: 'M'/'F' (o maschio/femmina)
    comune_nato: nome del comune (usato per il codice CUP/Belfiore)
    """
    if isinstance(data_nascita, str):
        data_nascita = datetime.strptime(data_nascita.strip(), "%Y-%m-%d").date()
    if isinstance(data_nascita, datetime):
        data_nascita = data_nascita.date()
    if not isinstance(data_nascita, date):
        raise ValueError("data_nascita non valida")

    sex = (sesso or "").strip().upper()
    if sex in ("F", "FEMMINA", "FEMMINILE", "DONNA"):
        is_female = True
    elif sex in ("M", "MASCHIO", "MASCHILE", "UOMO"):
        is_female = False
    else:
        raise ValueError("sesso non valido (usa M o F)")

    if not nome or not cognome:
        raise ValueError("nome e cognome obbligatori")

    cup = _cup_for(comune_nato)
    if not cup:
        raise ValueError("Comune di nascita non riconosciuto: %s" % comune_nato)

    cf15 = (
        _extract3_cognome(cognome)
        + _extract3_nome(nome)
        + "%02d" % (data_nascita.year % 100)
        + MESE[data_nascita.month]
        + "%02d" % (data_nascita.day + (40 if is_female else 0))
        + cup
    )
    if len(cf15) != 15:
        raise ValueError("Errore interno: lunghezza CF errata")
    return cf15 + _check_digit(cf15)
