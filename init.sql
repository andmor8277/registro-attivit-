INSERT INTO gruppi (nome) VALUES
  ('PRIMO GRUPPO'),('SECONDO GRUPPO'),('TERZO GRUPPO'),('PORTIERI')
ON CONFLICT DO NOTHING;
INSERT INTO codici (codice, descrizione, tipo) VALUES
  ('X',  'Presenza',             'presenza'),
  ('AG', 'Assente giustificato', 'assenza'),
  ('Ai', 'Infortunio',           'assenza'),
  ('AS', 'Assente',              'assenza'),
  ('R',  'Recupero',             'extra'),
  ('P',  'Permesso',             'extra')
ON CONFLICT DO NOTHING;
