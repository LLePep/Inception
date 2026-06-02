#!/bin/sh
set -e # Arrête le script immédiatement si une commande échoue

echo "=== Démarrage du script d'initialisation MariaDB ==="

# -------------------------------------------------------------------------
# 1. PRÉPARATION DE L'ENVIRONNEMENT LINUX
# -------------------------------------------------------------------------

#check du directory des logs et creation si il n'existe pas
if [ ! -d "/var/log/mysql" ]; then
    echo "Création du dossier de logs..."
    mkdir -p /var/log/mysql
fi

#check du directory du "PID, socket" et creation si il n'existe pas
if [ ! -d "/var/run/mysqld" ]; then
    mkdir -p /var/run/mysqld
fi

# Application des permissions strictes
echo "Application des permissions pour l'utilisateur mysql..."
chmod 2750 /var/log/mysql
chown -R mysql:mysql /var/log/mysql
chown -R mysql:mysql /var/run/mysqld
chown -R mysql:mysql /var/lib/mysql

# -------------------------------------------------------------------------
# 2. INITIALISATION DU DOSSIER DE DONNÉES (Si vide)
# -------------------------------------------------------------------------
# Si le volume lié à /var/lib/mysql est tout neuf, il faut installer les 
# tables systèmes de base de MariaDB.
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Première installation : Initialisation du data directory..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

# -------------------------------------------------------------------------
# 3. SÉCURISATION ET CRÉATION DE LA BASE WORDPRESS
# -------------------------------------------------------------------------
# Pour lancer des commandes SQL sans ouvrir le réseau aux pirates, on démarre
# MariaDB temporairement en tâche de fond, accessible UNIQUEMENT via le socket.

echo "Démarrage temporaire de MariaDB pour la configuration initiale..."
mariadbd --user=mysql --skip-networking &
pid="$!"

# On attend que le fichier socket soit créé avant d'envoyer des commandes
until [ -S /run/mysqld/mysqld.sock ]; do
    echo "Attente du socket MariaDB..."
    sleep 1
done

# Exécution des commandes SQL de configuration via le socket
# (Utilise les variables d'environnement de ton fichier .env)
echo "Configuration des utilisateurs et de la base de données..."
mariadb -u root <<EOF
-- Supprimer les utilisateurs anonymes et la base de test (Sécurité)
ALTER USER 'root'@'localhost' IDENTIFIED BY '${SQL_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Création de la base de données pour WordPress
CREATE DATABASE IF NOT EXISTS \`${SQL_DATABASE}\`;

-- Création de l'utilisateur WordPress et attribution des droits
CREATE USER IF NOT EXISTS '${SQL_USER}'@'%' IDENTIFIED BY '${SQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${SQL_DATABASE}\`.* TO '${SQL_USER}'@'%';

-- Appliquer les changements immédiatement
FLUSH PRIVILEGES;
EOF

# On éteint proprement le MariaDB temporaire
echo "Arrêt du MariaDB temporaire..."
kill -s TERM "$pid"
wait "$pid"

echo "=== Configuration terminée avec succès ! ==="

# -------------------------------------------------------------------------
# 4. LANCEMENT OFFICIEL DU SERVEUR
# -------------------------------------------------------------------------
# Le "exec" permet à MariaDB de devenir le processus principal (PID 1) du conteneur.
# Il va lire ton fichier 50-server.cnf et écouter sur le réseau (0.0.0.0) grâce à lui.
exec mariadbd --user=mysql