FROM nginx:alpine

RUN apk add --no-cache tcpdump

COPY reverse-proxy.conf.template /etc/nginx/templates/reverse-proxy.conf.template
