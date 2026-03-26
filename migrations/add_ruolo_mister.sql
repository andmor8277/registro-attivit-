-- Add ruolo field to utente_categorie (mister, allenatore, etc.)
ALTER TABLE utente_categorie ADD COLUMN IF NOT EXISTS ruolo VARCHAR(50);
