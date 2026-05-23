ARG base=debian

ARG version=bookworm-slim

FROM $base:$version

RUN apt update && apt install -y \
    nginx \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

COPY certificat/nginx-selfsigned.crt /etc/nginx/ssl/nginx-selfsigned.crt

COPY certificat/nginx-selfsigned.key /etc/nginx/ssl/nginx-selfsigned.key

COPY config_ssl.txt /etc/

EXPOSE 9000 443

ENTRYPOINT [ "nginx" ]

CMD [ "-g", "daemon off;" ]
