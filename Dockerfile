FROM node:16-alpine AS webapp
ENV BUILD=20220211-001
RUN apk add git && git clone https://github.com/sparkeh/homer-ui /app
WORKDIR /app
RUN npm install && npm install -g @angular/cli && npm run build

FROM golang:alpine AS webapi
ENV BUILD=20220211-001
RUN apk --update add git make
COPY . /homer-app
WORKDIR /homer-app
RUN make modules && make all

FROM alpine
WORKDIR /

RUN apk --update add bash sed tshark libcap shadow

RUN setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' /usr/bin/tshark && \
    setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' /usr/bin/dumpcap && \
    addgroup -S wireshark || true && \
    chown root:wireshark /usr/bin/dumpcap && \
    chmod 755 /usr/bin/tshark

RUN mkdir -p /usr/local/homer /tmp/homer && chmod 777 /tmp/homer

COPY --from=webapi /homer-app/homer-app .
COPY --from=webapi /homer-app/docker/webapp_config.json /usr/local/homer/etc/webapp_config.json
COPY --from=webapi /homer-app/swagger.json /usr/local/homer/etc/swagger.json
COPY --from=webapp /app/dist/homer-ui /usr/local/homer/dist

COPY ./docker/docker-entrypoint.sh /
COPY ./docker/docker-entrypoint.d/* /docker-entrypoint.d/
RUN chmod +x /docker-entrypoint.d/* /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/homer-app", "-webapp-config-path=/usr/local/homer/etc"]