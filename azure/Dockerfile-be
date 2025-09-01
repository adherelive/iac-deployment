FROM gagneet/ubuntulibs
# Install build-essential
RUN apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*
# RUN useradd -d /home/azureuser -m -s /bin/bash azureuser
# Get the current Git commit hash and set it as a build argument
ARG COMMIT_HASH=unknown
LABEL commit_hash=$COMMIT_HASH
LABEL application="adherelive-backend"
LABEL owner="AdhereLive Pvt Ltd"
RUN mkdir -p /usr/src/app
RUN mkdir -p /usr/src/app/public
WORKDIR /usr/src/app
COPY package.json /usr/src/app
COPY package-lock.json /usr/src/app
RUN npm config set registry https://registry.npmjs.org/ --global
RUN npm install && npm cache clean --force --loglevel=error
COPY . /usr/src/app
COPY env_files/.node_env_demo /usr/src/app/.env
EXPOSE 5000
CMD ["npm", "start"]
HEALTHCHECK NONE