INSERT INTO gruppi (nome) VALUES
  ('PRIMO GRUPPO'),('SECONDO GRUPPO'),('TERZO GRUPPO'),('PORTIERI')
ON CONFLICT DO NOTHING;
INSERT INTO codici (codice, descrizione, tipo) VALUES
  ('X',  'Presenza',             'presenza'),
  ('AG', 'Assente giustificato', 'assenza'),
  ('AI', 'Assente ingiustificato', 'assenza'),
  ('I', 'Infortunato',           'assenza'),
  ('R',  'Recupero altra cat.',  'extra')
ON CONFLICT DO NOTHING;
