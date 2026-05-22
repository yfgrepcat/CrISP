FROM nginx:alpine

COPY ./intranet /usr/share/nginx/html/intranet
COPY ./public /usr/share/nginx/html/public

RUN rm /etc/nginx/conf.d/default.conf
COPY ./web.conf /etc/nginx/conf.d/serveurs.conf

EXPOSE 80
EXPOSE 6767