ARG base=debian

ARG version=bookworm

FROM $base:$version

RUN apt update && apt install -y \
    mariadb-client \
    mariadb-server \
    galera-4 \
    && rm -rf /var/lib/apt/lists/*
    
COPY conf/50-server.cnf	/etc/mysql/mariadb.conf.d/50-server.cnf

COPY conf/configure /usr/local/bin/configure.sh

RUN chmod +x /usr/local/bin/configure.sh

EXPOSE 3306

ENTRYPOINT [ "/usr/local/bin/configure.sh" ]
