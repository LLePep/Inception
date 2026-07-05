# Inception — Dockerized Web Infrastructure

## Services

The project provides three services :

- **Nginx** : reverse-proxy, first entry point of the infrastructure. It handles TLS encryption and forwards requests to WordPress.
- **WordPress** : web server that manages dynamic pages via PHP-FPM.
- **MariaDB** : database that stores all content and user data. WordPress queries it via SQL requests.

---

## Start & Stop

Before the first launch, fill in your credentials (see [Credentials](#credentials) section).

```bash
make        # builds images and starts containers
make up     # restarts containers without rebuilding images
make down   # stops containers
make clean  # stops containers and removes images
make fclean # make clean + removes volumes and data
make re     # rebuilds everything from scratch
```

> ⚠️ `make fclean` permanently destroys all your WordPress and MariaDB data.

---

## Access the Website and Administration Panel

| Page | URL |
|------|-----|
| Website | https://lpalabos.42.fr |
| Admin panel | https://lpalabos.42.fr/wp-admin |

> The site uses TLS 1.2/1.3 with a self-signed certificate (not submitted to a CA).
> Your browser will display a security warning — click **"Advanced"** then **"Proceed"** to continue.

---

## Credentials

### Environment variables
Fill in the `srcs/.env` file :

```env
DOMAIN_NAME=lpalabos.42.fr
MYSQL_DATABASE=db_lpalabos
MYSQL_USER=          # MariaDB username
WP_TITLE=            # WordPress site title
WP_USER=             # WordPress admin login
WP_EMAIL=            # WordPress admin email
```

### Passwords
Fill in the following files **before** running `make` :

```
srcs/secrets/db_root_password.txt  → MariaDB root password
srcs/secrets/db_password.txt       → MariaDB user password
srcs/secrets/wp_password.txt       → WordPress admin password
```

> The WordPress admin login corresponds to `WP_USER` in `srcs/.env`.

---

## Check that the Infrastructure is Running

```bash
docker ps               # checks that all 3 containers are "Up"
docker logs nginx       # incoming request logs
docker logs wordpress   # PHP-FPM logs
docker logs mariadb     # database logs
```

If a container is in `Exited` state :
1. Check its logs to identify the error : `docker logs <container>`
2. Restart with `make re`