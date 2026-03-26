-- Add dati fields to persone table
ALTER TABLE persone ADD COLUMN IF NOT EXISTS data_nascita DATE;
ALTER TABLE persone ADD COLUMN IF NOT EXISTS codice_fiscale VARCHAR(16);
ALTER TABLE persone ADD COLUMN IF NOT EXISTS telefono VARCHAR(20);
ALTER TABLE persone ADD COLUMN IF NOT EXISTS matricola VARCHAR(50);
