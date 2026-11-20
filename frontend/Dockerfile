FROM node:20-alpine AS build
WORKDIR /app
# Il lock file va copiato E usato. `npm install` senza lock risolve le dipendenze a ogni build, e il
# 2026-11-20 e' successo che il registry rispondesse 404 sul tarball di
# @babel/plugin-transform-explicit-resource-management 7.29.15 (versione pubblicata senza tarball):
# build del frontend fallita, container frontend mai creato, DEV giu' con nessun container. `npm ci`
# installa ESATTAMENTE il lock, quindi la build non dipende da cosa pubblica Babel nel frattempo.
# Se il lock divergesse da package.json, `npm ci` fallisce dicendo perche': e' il comportamento voluto,
# perche' una build che cambia da sola non e' una build
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
