#!/bin/bash

set -e

echo "Starting MariaDB initialization..."

# Sécurité : On s'assure que le dossier du socket existe et appartient à mysql
mkdir -p /var/run/mysqld
chown -R mysql:mysql /var/run/mysqld

# Initialize MySQL data directory if it doesn't exist
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing data directory..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

# Start the server (CORRECTION : chemin /var/run/mysqld/)
echo "Starting temporary MariaDB server for setup..."
mysqld --skip-networking --socket=/var/run/mysqld/mysqld.sock --user=mysql &
pid="$!"

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
until mysqladmin --socket=/var/run/mysqld/mysqld.sock ping >/dev/null 2>&1; do
    sleep 1
done
echo "MariaDB is ready!"

# Run setup SQL (CORRECTION : chemin /var/run/mysqld/)
echo "Running setup SQL..."
mysql --socket=/var/run/mysqld/mysqld.sock -u root << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

# Shut down temporary server (CORRECTION : chemin /var/run/mysqld/)
echo "Shutting down temporary MariaDB..."
mysqladmin --socket=/var/run/mysqld/mysqld.sock -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown

wait "$pid" || true

echo "Initialization complete. Starting MariaDB normally..."
exec mysqld