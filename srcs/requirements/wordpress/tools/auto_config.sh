#!/bin/bash

sleep 10

if [ ! -f /var/www/wordpress/wp-config.php ]; then

    cd /var/www/html

	wp config create	--allow-root \
	--dbname=$SQL_DATABASE \
	--dbuser=$SQL_USER \
	--dbpass=$SQL_PASSWORD \
    --dbhost=mariadb:3306 --path='/var/www/html'
    wp core install --url=https://localhost:443 \
    --title=my_site \
    --admin_user=random \
    --admin_password=random \
    --admin_email=adiosbahamas@gmail.com \
    --allow-root \
    --skip-email
    wp user create username username@gmail.com \
    --allow-root \
    --user_pass=username_password
fi

exec php-fpm8.2 -F