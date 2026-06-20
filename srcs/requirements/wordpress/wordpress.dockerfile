ARG base=debian

ARG version=bookworm-slim

FROM $base:$version

RUN apt update && apt install -y \
    php8.2 \
    php8.2-fpm \
    php8.2-mysql \
    mariadb-client \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://fr.wordpress.org/wordpress-7.0-fr_FR.tar.gz -P /var/www \
    && cd /var/www && tar -xzf wordpress-7.0-fr_FR.tar.gz && rm wordpress-7.0-fr_FR.tar.gz \
    && chown -R www-data:www-data /var/www/wordpress

RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

COPY conf/php-fpm.conf /etc/php/8.2/fpm/php-fpm.conf

COPY tools/auto_config.sh /usr/local/bin/auto_config.sh
RUN chmod +x usr/local/bin/auto_config.sh

EXPOSE 9000

ENTRYPOINT [ "/usr/local/bin/auto_config.sh" ]