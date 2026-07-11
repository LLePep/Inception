#!/bin/bash

set -e

MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
MYSQL_PASSWORD=$(cat /run/secrets/db_password)

echo "Starting MariaDB initialization..."

#logs and volume
mkdir -p /var/run/mysqld /var/log/mysql
chown -R mysql:mysql /var/run/mysqld /var/log/mysql

# Initialize MySQL data directory if it doesn't exist
if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then

    echo "Initializing data directory..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null

    # Start the server
    echo "Starting temporary MariaDB server for setup..."
    mysqld --skip-networking --socket=/var/run/mysqld/mysqld.sock --user=mysql &
    pid="$!"

    # Wait for MariaDB to be ready
    echo "Waiting for MariaDB to be ready..."
    until mysqladmin --socket=/var/run/mysqld/mysqld.sock ping >/dev/null 2>&1; do
        sleep 1
    done
    echo "MariaDB is ready!"

    # Run setup SQL
    echo "Running setup SQL..."
    mysql --socket=/var/run/mysqld/mysqld.sock -u root << EOF
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
    CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
    GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOF

    echo "Shutting down temporary MariaDB..."
    kill -s TERM "$pid"

    wait "$pid" || true

    rm -f /var/run/mysqld/mysqld.pid
    rm -f /var/run/mysqld/mysqld.sock

    echo "Initialization complete. Starting MariaDB normally..."

else
    echo "Recuperation sucess"
fi

exec mysqld