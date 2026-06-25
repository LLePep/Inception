#!/bin/bash

set -e

#secrets
if [ -f "/run/secrets/mysql_root_password" ]; then
  	MYSQL_ROOT_PASSWORD=$(cat /run/secrets/mysql_root_password)
else
  	echo "Error: mysql_root_password secret not found"
  	exit 1
fi

if [ -f "/run/secrets/mysql_password" ]; then
	MYSQL_PASSWORD=$(cat /run/secrets/mysql_password)
else
  	echo "Error: mysql_password secret not found"
  	exit 1
fi

if [ -f "/run/secrets/mysql_healthcheck_password" ]; then
	MYSQL_HEALTHCHECK_PASSWORD=$(cat /run/secrets/mysql_healthcheck_password)
else
	echo "Error: mysql_healthcheck_password secret not found"
	exit 1
fi

if [ -f "/run/secrets/mysql_user" ]; then
	MYSQL_USER=$(cat /run/secrets/mysql_user)
else
  	echo "Error: mysql_user secret not found"
  	exit 1
fi

if [ -f "/run/secrets/mysql_database" ]; then
	MYSQL_DATABASE=$(cat /run/secrets/mysql_database)
else
  	echo "Error: mysql_database secret not found"
  	exit 1
fi

#directory ownership and permissions
chown -R mysql:mysql /var/lib/mysql
chown -R mysql:mysql /run/mysqld
chmod -R 755 /var/lib/mysql
chmod -R 755 /run/mysqld

#init db
if [ ! -d "/var/lib/mysql/$MYSQL_DATABASE" ]; then
  echo "initializing database..."
  mysql_install_db --user=mysql --datadir=/var/lib/mysql
  mysqld --user=mysql --datadir=/var/lib/mysql &
  MYSQL_PID=$!

  while ! mysqladmin ping --silent 2>/dev/null; do
      echo "waiting for MySQL to start..."
      sleep 2
  done

  mysql << EOF || { echo "SQL setup failed"; kill $MYSQL_PID; wait $MYSQL_PID; exit 1; }
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password;
SET PASSWORD = PASSWORD('${MYSQL_ROOT_PASSWORD}');
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
CREATE USER IF NOT EXISTS 'healthcheck'@'localhost' IDENTIFIED BY '${MYSQL_HEALTHCHECK_PASSWORD}';
GRANT USAGE ON *.* TO 'healthcheck'@'localhost';
FLUSH PRIVILEGES;
EOF

  kill $MYSQL_PID
  wait $MYSQL_PID

  echo "database successfully initializated"
else
  echo "database already exists"
fi

echo "starting MySQL server..."
exec mysqld --user=mysql --datadir=/var/lib/mysql