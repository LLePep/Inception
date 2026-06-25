#!/bin/bash

sleep 10

if [ ! -f /var/www/html/wp-config.php ]; then

    cd /var/www/html

    wp core download --allow-root

	wp config create	--allow-root \
	--dbname=$MYSQL_DATABASE \
	--dbuser=$MYSQL_USER \
	--dbpass=$MYSQL_PASSWORD \
    --dbhost=mariadb:3306 --path='/var/www/html'
    wp core install --url=https://$DOMAIN_NAME:443 \
    --title=$WP_TITLE \
    --admin_user=$WP_USER \
    --admin_password=$WP_PASSWORD \
    --admin_email=$WP_EMAIL \
    --allow-root \
    --path='/var/www/html' \
    --skip-email
    wp user create username username@gmail.com \
    --allow-root \
    --role=editor \
    --user_pass=username_password
fi

exec php-fpm8.2 -F