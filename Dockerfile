# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: base — instala dependencias (reutilizado por los stages siguientes)
# ─────────────────────────────────────────────────────────────────────────────
FROM node:22-alpine AS base
WORKDIR /app
COPY package*.json ./
RUN npm ci

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: test — ejecuta los tests unitarios
# Si algún test falla, el build se detiene aquí (exit code ≠ 0)
# ─────────────────────────────────────────────────────────────────────────────
FROM base AS test
COPY . .
RUN npm run test

# ─────────────────────────────────────────────────────────────────────────────
# Stage 3: dev — servidor de desarrollo con hot-reload (puerto 3000)
# Uso: docker build --target dev -t taskapp:dev .
#      docker run -p 3000:3000 -v $(pwd)/src:/app/src taskapp:dev
# ─────────────────────────────────────────────────────────────────────────────
FROM base AS dev
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]

# ─────────────────────────────────────────────────────────────────────────────
# Stage 4: build — genera los archivos estáticos en /app/dist
# Depende de que los tests hayan pasado (hereda de test)
# ─────────────────────────────────────────────────────────────────────────────
FROM test AS build
RUN npm run build

# ─────────────────────────────────────────────────────────────────────────────
# Stage 5: production — imagen final con Nginx (solo archivos estáticos)
# No contiene Node.js ni el código fuente → imagen mínima y segura
# ─────────────────────────────────────────────────────────────────────────────
FROM nginx:stable-alpine AS production
# Copia la configuración personalizada de Nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf
# Copia los archivos estáticos generados en el stage anterior
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]