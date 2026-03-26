-- Add user fields to utenti table
ALTER TABLE utenti ADD COLUMN IF NOT EXISTS nome VARCHAR(100) NOT NULL DEFAULT '';
ALTER TABLE utenti ADD COLUMN IF NOT EXISTS cognome VARCHAR(100) NOT NULL DEFAULT '';
ALTER TABLE utenti ADD COLUMN IF NOT EXISTS data_nascita DATE NOT NULL DEFAULT '1990-01-01';
ALTER TABLE utenti ADD COLUMN IF NOT EXISTS codice_fiscale VARCHAR(16) NOT NULL DEFAULT '';
ALTER TABLE utenti ADD COLUMN IF NOT EXISTS cellulare VARCHAR(20) NOT NULL DEFAULT '';
ALTER TABLE utenti ADD COLUMN IF NOT EXISTS tesserino VARCHAR(50);

-- Update existing users with default values
UPDATE utenti SET nome = 'Admin' WHERE nome = '' AND username = 'admin';
UPDATE utenti SET cognome = 'Sistema' WHERE cognome = '' AND username = 'admin';
UPDATE utenti SET nome = 'Utente' WHERE nome = '' AND username != 'admin';
