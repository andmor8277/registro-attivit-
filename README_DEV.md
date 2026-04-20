
## Database Locale

Per avviare il backend locale con il database PostgreSQL:

### 1. Avviare PostgreSQL
```bash
mkdir -p /tmp/pgsocket /tmp/pgdata
pg_ctl -D /tmp/pgdata -o "-p 5433 -k /tmp/pgsocket" -l /tmp/pg.log start 2>/dev/null || pg_ctl -D /tmp/pgdata -l /tmp/pg.log start
sleep 2
```

### 2. Creare utente e database (solo prima volta)
```bash
psql -h /tmp/pgsocket -p 5433 -d postgres -c "CREATE USER registro_user WITH PASSWORD 'REMOVED' CREATEDB SUPERUSER;"
psql -h /tmp/pgsocket -p 5433 -d postgres -c "CREATE DATABASE registro OWNER registro_user;"
```

### 3. Ripristinare dump da produzione (opzionale)
```bash
# Dalla macchina remota:
ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose exec -T db pg_dump -U registro_user -d registro" > /tmp/registro_dump.sql

# Importare nel database locale:
psql -h /tmp/pgsocket -p 5433 -d registro -U registro_user -f /tmp/registro_dump.sql
```

### 4. Avviare backend
```bash
cd /home/andrea/registro_presenze/backend
export DATABASE_URL="postgresql://registro_user:REMOVED@/registro?host=/tmp/pgsocket&port=5433"
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Coordinate database
- Host socket: /tmp/pgsocket
- Porta: 5433
- Utente: registro_user
- Password: REMOVED
- Database: registro
- URL completo: postgresql://registro_user:REMOVED@/registro?host=/tmp/pgsocket&port=5433

### Frontend dev
```bash
cd /home/andrea/registro_presenze/frontend
npm run dev
```
