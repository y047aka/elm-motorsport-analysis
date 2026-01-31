FROM mcr.microsoft.com/playwright:v1.57.0-noble

WORKDIR /deps

COPY package.json package-lock.json ./
COPY app/package.json ./app/
COPY package/package.json ./package/
COPY review/package.json ./review/

RUN npm ci

WORKDIR /work
