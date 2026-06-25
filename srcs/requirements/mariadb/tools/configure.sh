#!/bin/bash

set -e

echo "Starting MariaDB initialization..."

#logs
mkdir -p /var/run/mysqld /var/log/mysql
chown -R mysql:mysql /var/run/mysqld /var/log/mysql

# Sécurité : On s'assure que le dossier du socket existe et appartient à mysql
mkdir -p /var/run/mysqld
chown -R mysql:mysql /var/run/mysqld

# Initialize MySQL data directory if it doesn't exist
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing data directory..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

# Start the server (CORRECTION : /var/run/mysqld/mysqld.sock)
echo "Starting temporary MariaDB server for setup..."
mysqld --skip-networking --socket=/var/run/mysqld/mysqld.sock --user=mysql &
pid="$!"

# Wait for MariaDB to be ready (CORRECTION : /var/run/mysqld/mysqld.sock)
echo "Waiting for MariaDB to be ready..."
until mysqladmin --socket=/var/run/mysqld/mysqld.sock ping >/dev/null 2>&1; do
    sleep 1
done
echo "MariaDB is ready!"

# Run setup SQL (CORRECTION : /var/run/mysqld/mysqld.sock)
echo "Running setup SQL..."
mysql --socket=/var/run/mysqld/mysqld.sock -u root << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

# Shut down temporary server (CORRECTION : /var/run/mysqld/mysqld.sock)
echo "Shutting down temporary MariaDB..."
mysqladmin --socket=/var/run/mysqld/mysqld.sock -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown

wait "$pid" || true

# Nettoyage des résidus pour éviter l'erreur 115
rm -f /var/run/mysqld/mysqld.pid
rm -f /var/run/mysqld/mysqld.sock

# CORRECTION : On lance mysqld SANS arguments de chemins. 
# Il va lire ton 'mysql.cnf' qui contient déjà les bons chemins propres !
echo "Initialization complete. Starting MariaDB normally..."
exec mysqld