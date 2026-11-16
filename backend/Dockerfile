FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN useradd --create-home appuser && chown -R appuser:appuser /app
USER appuser
# --forwarded-allow-ips non puo essere *: con * uvicorn si fida di X-Forwarded-For da chiunque,
# e poiche' openresty (sul router) ACCORPA il nostro header invece di sostituirlo, un attaccante
# si attribuisce un IP fittizio a ogni richiesta e aggira ogni rate limit. Verificato: con
# "X-Forwarded-For: 203.0.113.77" il log uvicorn registra 203.0.113.77 come client, mentre senza
# header registra l'IP reale (88.35.34.142). Si fidano solo dei proxy Docker: le richieste che
# arrivano dritte su :8000 (porta pubblicata su 0.0.0.0) non possono piu' falsificare l'IP.
# Attenzione: questo NON chiude il percorso proxy, dove il peer TCP e' comunque il container
# frontend. Per quello serve openresty che faccia "proxy_set_header X-Forwarded-For $remote_addr"
# (sostituzione, non accorpamento), oppure un blocco per username indipendente dall'IP.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4", "--proxy-headers", "--forwarded-allow-ips=127.0.0.1,172.16.0.0/12"]
