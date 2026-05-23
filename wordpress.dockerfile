ARG base=php

ARG version=8.4-fpm-bookworm

FROM $base:$version

RUN apt update && apt install -y \
    libpng-dev \
    libjpeg-dev \
    libwebp-dev \
    && docker-php-ext-configure gd --with-jpeg --with-webp \
    && docker-php-ext-install -y gd mysqli pdo_mysql \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 9000

EXPOSE 3306
