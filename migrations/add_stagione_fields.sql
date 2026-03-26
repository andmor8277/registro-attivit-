-- Migrazione per aggiungere i campi stagione, is_portieri, is_archiviata
-- Esegui questo script sul database PostgreSQL

-- Aggiunge la colonna stagione (anno inizio stagione calcistica)
ALTER TABLE categorie ADD COLUMN IF NOT EXISTS stagione INTEGER;

-- Aggiunge la colonna is_portieri (1 = portieri cross-year)
ALTER TABLE categorie ADD COLUMN IF NOT EXISTS is_portieri INTEGER DEFAULT 0;

-- Aggiunge la colonna is_archiviata (1 = stagione archiviata)
ALTER TABLE categorie ADD COLUMN IF NOT EXISTS is_archiviata INTEGER DEFAULT 0;

-- Imposta la stagione corrente per tutte le categorie esistenti
-- NOTA: Modifica il valore 2025 con l'anno di inizio della tua stagione corrente
-- Esempio: per la stagione 2025/2026 usa 2025
UPDATE categorie SET stagione = 2025 WHERE stagione IS NULL;

-- Verifica che le colonne siano state aggiunte
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'categorie' 
AND column_name IN ('stagione', 'is_portieri', 'is_archiviata');
