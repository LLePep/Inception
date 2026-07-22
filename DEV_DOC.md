# Developer Documentation

---

# Set Up Your Environment

## Prerequisites

- A Linux OS
- Docker
- Make and Git:
```bash
sudo apt install make git
```

## Docker Installation

Choose between Docker Desktop (GUI) or Docker Engine (CLI only) :
- [Docker Engine](https://docs.docker.com/engine/install/)
- [Docker Desktop](https://docs.docker.com/desktop/)

Verify your installation :
```bash
docker run hello-world
```

## Clone the Repository

```bash
git clone https://github.com/LLePep/Docker.git <folder_name>
cd <folder_name>
```

## Credentials

### Environment Variables

Fill in `srcs/.env` :

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

# Build & Launch

```bash
make        # builds images and starts containers
make up     # restarts containers without rebuilding images
make down   # stops containers
make clean  # stops containers and removes images
make fclean # make clean + removes volumes and data
make re     # rebuilds everything from scratch
```

> ⚠️ `make fclean` permanently destroys all WordPress and MariaDB data.

---

# Manage Containers and Volumes

## Containers

```bash
docker ps                        # list running containers
docker ps -a                     # list all containers (including stopped)
docker logs <service_name>       # show logs of a service
docker exec -it <service_name> bash  # open a shell inside a container
docker stop <service_name>       # stop a specific container
docker rmi <image_name>          # remove a specific image
```

## Volumes

```bash
docker volume ls                      # list all volumes
docker volume inspect <volume_name>   # inspect a specific volume
docker volume prune                   # remove all unused volumes
```

## Database

```bash
# Connect to MariaDB
docker exec -it mariadb mariadb -u $MYSQL_USER -p$(cat srcs/secrets/db_password.txt) $MYSQL_DATABASE
```

Useful SQL commands once connected :

```sql
-- Explore
SHOW TABLES;
SELECT user_login, user_email FROM wp_users;
SELECT option_name, option_value FROM wp_options WHERE option_name IN ('siteurl', 'home');

-- Create a table
CREATE TABLE name (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(50));

-- Insert data
INSERT INTO table_name (id, name) VALUES (10, 'Victor');

-- Delete a table
DROP TABLE name;
```

---

# Data Persistence

Project data is stored on the host machine and mounted into containers via bind volumes :

| Data | Host path | Container path |
|------|-----------|----------------|
| WordPress files | `/home/lpalabos/data/wordpress` | `/var/www/html` |
| MariaDB database | `/home/lpalabos/data/mariadb` | `/var/lib/mysql` |

Data persists across `make down` / `make up` cycles because it lives on the host, not inside the containers.

> ⚠️ Only `make fclean` permanently deletes this data.