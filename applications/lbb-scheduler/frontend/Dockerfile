# ==============================================================
# LBBS Frontend Dockerfile — React Build + Nginx
# ==============================================================
# Stage 1: Build React app (node)
# Stage 2: Serve with Nginx (tiny production image)
# ==============================================================

# --- Stage 1: Build ---
FROM node:20-alpine AS build

WORKDIR /app

# Install dependencies first (cached layer)
COPY package.json package-lock.json ./
RUN npm ci --quiet

# Copy source code and build
COPY . .
RUN npm run build

# --- Stage 2: Serve ---
FROM nginx:alpine

# Copy built files to Nginx
COPY --from=build /app/dist /usr/share/nginx/html

# Copy Nginx config (handles React Router + API proxy)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

# Health check


CMD ["nginx", "-g", "daemon off;"]
