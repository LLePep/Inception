# Notes Techniques — Inception

---

# Docker

## Qu'est-ce qu'un daemon ?

Un daemon est un programme qui s'exécute en arrière-plan, lancé souvent au démarrage avec les droits root. Dès qu'il reçoit une commande ou une requête spécifique, il exécute ce pour quoi il est programmé.

Exemples : `cron`, `httpd`, `syslog`

## Alpine vs Debian

- **Alpine** : utilise `musl` — légère, rapide, orientée sécurité, moins compatible.
- **Debian** : utilise `glibc` — plus lourde, bien plus adaptable, optimisée pour les projets modernes.

Toute deux sont des librairies C, qui sont mise a jour. Attention glibc est bien plus tenu a jour que musl.

---

## musl vs glibc

| | musl | glibc |
|--|------|-------|
| Taille | Légère | Lourde |
| Vitesse de compilation | Rapide | Plus lente |
| Compatibilité | Limitée | Très large |
| Usage | Projets légers, sécurité | Projets modernes complexes |

---

## Distroless — la sécurité optimale

Les images Distroless (maintenues par Google) embarquent uniquement le strict minimum pour faire tourner une application. Zéro shell, zéro package manager, zéro outil superflu.

Le principal défi est le **multi-stage build** : on utilise plusieurs `FROM` successifs dans le Dockerfile. L'idée est d'utiliser une distribution classique pour installer toutes les dépendances, puis de les `COPY` vers l'image Distroless finale. Résultat : une image minuscule et très difficile à exploiter pour un attaquant.

---

## Bonnes pratiques Dockerfile

- Organiser les instructions du **moins changeant au plus changeant** (en haut ce qui bouge rarement) pour optimiser le cache de build.
- Penser en **layers** : chaque instruction crée une couche.
- Utiliser `--no-install-recommends` pour éviter les packages inutiles.
- Utiliser `.dockerignore` (même principe que `.gitignore`).
- Utiliser `--no-cache` pour forcer un build propre.
- Utiliser `--pull` pour forcer le pull de la dernière version de l'image de base.
- Viser des images **éphémères** : un container doit pouvoir être détruit et recréé sans perte.

---

## Shell form vs Exec form

```dockerfile
INSTRUCTION command param1 param2          # shell form
INSTRUCTION ["executable","param1","param2"] # exec form
```

**Shell form** : exécute via `/bin/sh -c`, le shell devient PID1 et l'application est PID2. Si Docker envoie un `SIGTERM`, `/bin/sh` ne le propage pas → l'application ne libère pas ses ressources → Docker envoie un `SIGKILL` brutal.

**Exec form** : l'application est directement PID1, elle reçoit les signaux système directement et peut s'arrêter proprement. **À préférer pour ENTRYPOINT et CMD.**

---

## Instructions Dockerfile

### FROM
Initialise une nouvelle session de construction. Définit l'image de base.
En multi-stage, on peut avoir plusieurs `FROM` successifs.

### RUN
Crée une couche lors du `docker build`. Préférer un seul appel au package manager par `RUN` pour minimiser le nombre de layers.

### ENTRYPOINT && CMD
- **ENTRYPOINT** : définit la commande principale (rarement surchargée, option `--entrypoint`).
- **CMD** : définit les arguments par défaut de la commande principale, facilement surchargeable.
Ils travaillent ensemble.

### LABEL
Crée des métadonnées dans l'image. Accessible via `docker inspect <image>`.

### ENV
Définit des variables d'environnement dans le container. Surchargeable avec `-e`. Persistantes au runtime.

### ARG
Définit des variables de **build-time** uniquement — elles n'existent plus au runtime.
⚠️ Ne jamais y mettre de données sensibles : elles restent visibles dans `docker history <image>`.
Différence clé avec ENV : ARG = uniquement pendant le build, ENV = disponible au runtime.

### COPY vs ADD
- `COPY <host-path> <image-path>` : copie simple depuis l'hôte vers le container.
- `ADD` : comme COPY mais gère aussi les URLs et l'extraction d'archives.
- **Règle** : toujours préférer `COPY`, utiliser `ADD` uniquement si l'extraction automatique est nécessaire.

### VOLUME
Crée un point de montage. Trois types :
- **Bind mount** : l'utilisateur spécifie le path entre son OS et le container.
- **Volume mount** : géré par Docker.
- **tmpfs mount** : durée de vie temporaire, data reset au stop/restart. Utile pour les données sensibles temporaires (tokens, sessions) car elles ne touchent jamais le disque.
- **Named pipes** : communication entre container et hôte, utile pour la CI/CD.

### WORKDIR
Définit le répertoire de travail pendant le build et à l'exécution.

### EXPOSE
**Purement documentaire.** N'ouvre aucun port réellement.
Dans un réseau Docker bridge, les containers communiquent entre eux **sans avoir besoin d'EXPOSE** — la communication se fait via le nom du service sur n'importe quel port sans restriction.
Le vrai mappage de port se fait avec `-p` ou `ports:` dans docker-compose.

---

## Docker Volumes — commandes

```bash
docker volume create <name>   # créer un volume
docker volume ls              # lister les volumes
docker volume rm <name>       # supprimer un volume
docker volume inspect <name>  # inspecter un volume
docker volume prune           # supprimer tous les volumes non utilisés

# Lancer un container avec un volume (bind mount)
docker run --rm -it -v <dossier_local>:<dossier_conteneur> <image>

# Lancer un container avec un volume nommé
docker run --rm -it -v <nom_volume>:<dossier_conteneur> <image>
```

⚠️ Si tu utilises un Bind Mount, pense à faire `chown -R 33:33` sur le dossier hôte (UID de www-data), sinon WordPress ne pourra pas installer de plugins ni uploader d'images.

---

## Réseau Docker

### Les 3 modes réseau

| Mode | Description | Usage |
|------|-------------|-------|
| `none` | Isolation totale, aucun réseau | Sécurité maximale |
| `bridge` | Réseau privé virtuel avec NAT | Usage standard |
| `host` | Partage direct de la pile réseau de l'hôte | ⚠️ Dangereux en prod |

### Bridge classique vs Bridge Docker

- **Bridge réseau classique** : connecte deux interfaces réseau au niveau L2 (liaison) pour partager le flux entre elles.
- **Bridge Docker** : crée un sous-réseau virtuel isolé avec NAT (Network Address Translation). Chaque container a sa propre adresse IP privée. Docker fournit un DNS interne pour résoudre les noms de services (ex: `mariadb`, `wordpress`). Repose sur les **Network Namespaces** Linux.

### Host Network
Le container partage **la pile réseau** de l'hôte. Le container utilise directement les interfaces réseau et les ports de la machine hôte → risque de conflit de ports.

### Mapper un port
```bash
docker run -p <port_hote>:<port_container> <image>
```

---

## Docker Compose

Fichier qui orchestre plusieurs containers, leurs dépendances, réseaux et volumes pour livrer une infrastructure opérationnelle. Lisible et rapide à comprendre.

### Watchtower
Outil qui surveille les containers en cours d'exécution et les **met à jour automatiquement** quand une nouvelle version de leur image est disponible sur le registry. Utile pour le CD (Continuous Deployment).

---

# Fichier de configuration MariaDB

## Structure du fichier

MariaDB découpe sa config en plusieurs sections pour des raisons de compatibilité historique :

| Section | Lu par |
|---------|--------|
| `[mysqld]` | Le daemon MariaDB uniquement |
| `[server]` | Le serveur + outils intégrés (ex: Galera) |
| `[mysql]` | Le client de connexion |
| `[mariadbd]` | Équivalent de `[mysqld]` mais spécifique à MariaDB (pas MySQL) |
| `[embedded]` | Pour le moteur embarqué dans une autre application (rare) |
| `[mariadb-11.8]` | Options spécifiques à une version précise |

---

## Directives de base

### `user = mysql`
Dès que MariaDB a fini de démarrer, il rétrograde ses privilèges et prend l'identité de l'utilisateur système `mysql` (droits très limités).

### `pid-file = /var/run/mysqld/mysqld.pid`
MariaDB écrit son PID dans ce fichier au démarrage. Permet au système ou à Docker de savoir si le process est toujours en vie.

### `datadir = /var/lib/mysql`
Emplacement physique où MariaDB stocke les vraies données : tables WordPress, utilisateurs, articles, mots de passe.

### `tmpdir = /tmp`
Dossier pour les fichiers temporaires (calculs intermédiaires). Supprimés dès que la requête est terminée.

### `skip-name-resolve`
Docker ne gère pas le Reverse DNS (IP → Nom). Sans cette directive, MariaDB tente une résolution DNS inverse à chaque connexion et attend un timeout. `skip-name-resolve` saute cette vérification inutile et élimine les temps d'attente.

### `bind-address = 0.0.0.0`
Par défaut à `127.0.0.1` (localhost uniquement). En Docker, les IPs sont dynamiques donc on ne peut pas écrire une IP fixe. `0.0.0.0` = écoute sur toutes les interfaces → WordPress peut contacter MariaDB depuis son container.

---

## Gestion des ressources

| Directive | Rôle |
|-----------|------|
| `key_buffer_size = 128M` | RAM pour les index MyISAM (WordPress utilise InnoDB, donc peu utile) |
| `max_allowed_packet = 1G` | Taille max d'une requête SQL (évite "MySQL server has gone away" sur gros imports) |
| `thread_stack = 192K` | Mémoire de travail allouée par thread (valeur standard Debian) |
| `thread_cache_size = 8` | Garde 8 threads en veille au lieu de les détruire/recréer à chaque requête |
| `myisam_recover_options = BACKUP` | Réparation auto des tables MyISAM corrompues après un crash, avec backup préalable |
| `max_connections = 100` | Fusible : max 100 clients simultanés, évite que MariaDB ne consomme toute la RAM |
| `table_open_cache = 64` | Garde 64 tables "ouvertes" en mémoire pour éviter des accès disque répétés |

---

## Logs

```ini
# Log général (ATTENTION : tueur de performances, uniquement pour debug court)
general_log_file = /var/log/mysql/mysql.log
general_log      = 1

# Log des erreurs
log_error = /var/log/mysql/error.log

# Log des requêtes lentes
log_slow_query_file = /var/log/mysql/mariadb-slow.log
log_slow_query_time = 10          # requête considérée lente si > 10s
log_slow_verbosity  = query_plan,explain  # détail du plan de requête
log-queries-not-using-indexes     # log si pas d'index utilisé (scan complet)
log_slow_min_examined_row_limit = 1000  # log si plus de 1000 lignes parcourues
```

Rappel permissions dossier logs :
```bash
mkdir -m 2750 /var/log/mysql
chown mysql /var/log/mysql
# 2750 : le "2" est le SetGID (force les nouveaux fichiers à hériter du groupe)
# 7 = rwx (user), 5 = r-x (group), 0 = --- (other)
```

---

## Réplication et scaling

```ini
server-id    = 1
log_bin      = /var/log/mysql/mysql-bin.log
expire_logs_days = 10
max_binlog_size  = 100M
```

Options utiles pour des infrastructures plus avancées avec réplication. À combiner avec **Galera** (clustering) et **MaxScale** (load balancer côté DB).

---

## SSL en réseau Docker interne

Non nécessaire dans notre cas. Nos containers sont dans un réseau privé Docker entièrement isolé et contrôlé. Le risque d'interception est nul. SSL/TLS entre services n'a de sens que si le trafic transite par Internet (DB dans des datacenters distants par exemple).

---

## InnoDB

WordPress utilise InnoDB (moteur moderne). La recommandation officielle est d'allouer 80% de la RAM système au buffer pool InnoDB :
```ini
innodb_buffer_pool_size = 8G  # à adapter selon la RAM disponible
```

---

# Fichier de configuration PHP-FPM (WordPress)

## Pool `[www]`

Le `[www]` crée un **pool** qui dicte le comportement du serveur WordPress. L'isolation en pools permet d'héberger plusieurs sites sur un même serveur : si l'un crashe, il n'impacte pas les autres.

### Utilisateur et groupe
```ini
user  = www-data
group = www-data
```
Propriétaire du process PHP-FPM.

### Écoute
```ini
listen = 0.0.0.0:9000
```
PHP-FPM écoute sur le port 9000 pour recevoir les requêtes FastCGI de nginx.

### Backlog
```ini
listen.backlog = 511
```
Nombre de connexions en attente pouvant s'empiler. Valeur `-1` sur BSD = illimité.
⚠️ Si modifié, il faut aussi ajuster la valeur côté OS Linux ET côté nginx, sinon le changement n'a aucun effet.

### Permissions Unix Socket — ACL
```ini
listen.acl_users  = www-data
listen.acl_groups = www-data
```
Les ACL (Access Control Lists) sont plus flexibles que les permissions Unix classiques (1 user, 1 groupe, les autres). Elles permettent d'attribuer des droits à plusieurs users/groupes sans limite.

> Les permissions Unix classiques sont limitées : 1 user, 1 groupe, les autres — avec uniquement r/w/x pour chacun. Les ACL comblent ce manque en permettant d'assigner des droits à n'importe quel utilisateur ou groupe, sans limitation du nombre.

⚠️ `listen.acl_users` ne fonctionne qu'avec les **Unix sockets**, pas avec les TCP sockets (`0.0.0.0:9000`). À commenter si on écoute en TCP.

### Niceness (priorité)
```ini
; process.priority = -19
```
De -19 (priorité maximale) à 20 (priorité minimale). Non défini par défaut.

### Process dumpable
```ini
; process.dumpable = yes
```
Par défaut désactivé. Quand PHP-FPM démarre en root puis passe sur `www-data`, Linux verrouille le dump mémoire. Cette option le réactive.
⚠️ Utile en dev pour débugger, **absolument à éviter en prod**.

---

## Modes de gestion des processus

| Mode | Comportement | Usage |
|------|-------------|-------|
| `static` | Nombre fixe de workers, tourne en permanence | Forte demande continue, performance max |
| `dynamic` | Crée/détruit des workers selon la demande | Infras moyennes avec trafic variable |
| `ondemand` | Crée des workers uniquement à la demande, les détruit à l'absence | Petites infras, économie de RAM |

```ini
pm = dynamic
pm.max_children    = 25   # max workers simultanés
pm.start_servers   = 5    # workers au démarrage
pm.min_spare_servers = 1  # min workers en attente
pm.max_spare_servers = 10 # max workers en attente
```

### `clear_env = no`
Par défaut PHP-FPM nettoie les variables d'environnement avant de les passer aux workers. `no` permet aux variables du container (comme celles du `.env`) d'être accessibles dans le code PHP via `getenv()`, `$_ENV`, `$_SERVER`.

---

# Fichier de configuration Nginx

## Structure générale

```nginx
server {
    # Bloc principal : définit un virtual host
}
```

Nginx peut héberger plusieurs sites sur le même serveur via plusieurs blocs `server`. Chaque bloc répond à un domaine ou un port différent.

---

## Directives expliquées

### Écoute et domaine
```nginx
listen 443 ssl;
listen [::]:443 ssl;
server_name lpalabos.42.fr;
```
- `listen 443 ssl` : écoute sur le port 443 en mode SSL/TLS (IPv4).
- `listen [::]:443 ssl` : même chose en IPv6.
- `server_name` : le domaine auquel ce bloc répond. Si la requête ne correspond pas, nginx l'ignore.

---

### SSL/TLS
```nginx
ssl_certificate     /etc/nginx/ssl/nginx-selfsigned.crt;
ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;
ssl_protocols       TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:...';
```
- `ssl_certificate` / `ssl_certificate_key` : chemin vers le certificat et sa clé privée.
- `ssl_protocols` : versions TLS autorisées. TLSv1.0 et TLSv1.1 sont dépréciés et désactivés — seuls TLS 1.2 et 1.3 sont autorisés (exigence du sujet Inception).
- `ssl_prefer_server_ciphers on` : force l'utilisation des cipher suites du serveur plutôt que celles proposées par le client.
- `ssl_ciphers` : liste des algorithmes de chiffrement autorisés. `ECDHE` = échange de clés basé sur les courbes elliptiques (Perfect Forward Secrecy), `AES-GCM` = chiffrement symétrique rapide et sûr.

---

### Racine et index
```nginx
root  /var/www/html;
index index.php index.html;
```
- `root` : dossier racine où nginx cherche les fichiers à servir. Correspond au volume WordPress monté.
- `index` : fichiers à servir par défaut si aucun fichier n'est spécifié dans l'URL. Nginx essaie `index.php` en premier, puis `index.html`.

---

### Location `/` — fichiers statiques
```nginx
location / {
    try_files $uri $uri/ /index.php?$args;
}
```
- `try_files` : nginx cherche d'abord le fichier exact (`$uri`), puis le dossier (`$uri/`), et si rien n'est trouvé il renvoie vers `index.php` avec les arguments. C'est ce qui permet les **URLs propres** de WordPress (permaliens) sans extension `.php` visible.

---

### Location `~ \.php$` — FastCGI vers PHP-FPM
```nginx
location ~ \.php$ {
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    fastcgi_pass            wordpress:9000;
    fastcgi_index           index.php;
    include                 fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_param HTTPS           on;
}
```
- `location ~ \.php$` : intercepte toutes les requêtes vers un fichier `.php` (le `~` indique une regex).
- `fastcgi_split_path_info` : sépare le chemin du script PHP du path info (utile pour certaines configs WordPress).
- `fastcgi_pass wordpress:9000` : envoie la requête au container WordPress sur le port 9000 via le protocole FastCGI. `wordpress` est résolu par le DNS interne Docker.
- `include fastcgi_params` : charge les variables standard FastCGI (méthode HTTP, query string, etc.).
- `fastcgi_param SCRIPT_FILENAME` : indique à PHP-FPM quel fichier exécuter. `$document_root` = `/var/www/html`, `$fastcgi_script_name` = le fichier `.php` demandé.
- `fastcgi_param HTTPS on` : informe WordPress qu'on est en HTTPS. Sans cette ligne, WordPress détecte HTTP et redirige → boucle infinie.