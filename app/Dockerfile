FROM node:20-alpine

WORKDIR /app

# Csak a csomagfájlok másolása első körben (cache-barát)
COPY package*.json ./

RUN npm install --omit=dev

# App forráskód másolása
COPY server.js ./

EXPOSE 8080

CMD ["node", "server.js"]
