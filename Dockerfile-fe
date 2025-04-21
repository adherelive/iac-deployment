FROM node:16.10.0 AS builder
# RUN useradd -d /home/azureuser -m -s /bin/bash azureuser
# Get the current Git commit hash and set it as a build argument
ARG COMMIT_HASH=unknown
LABEL commit_hash=$COMMIT_HASH
LABEL application="adherelive-frontend"
LABEL owner="AdhereLive Pvt Ltd"
# Stage 1
RUN mkdir -p /code
RUN mkdir -p /code/public
WORKDIR /code
COPY package.json ./
COPY package-lock.json ./
RUN npm install && npm cache clean --force --loglevel=error
COPY . .
RUN cp env_files/.env_demo .env
RUN npm run build
# Stage 2
FROM nginx
EXPOSE 80
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /code/build/ /usr/share/nginx/html
HEALTHCHECK NONE