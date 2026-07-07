*This project has been created as part of the 42 curriculum by lpalabos.*

# INCEPTION

## Description

The goal of this project is to build a complete web infrastructure using Docker, composed of three services: **Nginx**, **WordPress + PHP-FPM**, and **MariaDB**. Each service runs in its own dedicated container, built from a custom Dockerfile based on Debian Bookworm.

### Docker in this Project

Docker is used to containerize each service independently. Rather than running everything on a single machine or VM, each service lives in its own isolated environment. They communicate through a private Docker bridge network and share data through persistent volumes.

The project does not use any pre-built images from Docker Hub (except the base Debian image). Every service is built from scratch using custom Dockerfiles.

### Main Design Choices

- **Nginx** is the sole entry point, handling TLS termination (TLS 1.2/1.3 only) and forwarding PHP requests to WordPress via FastCGI.
- **WordPress** runs with PHP-FPM, which manages a pool of PHP worker processes ready to handle requests.
- **MariaDB** stores all WordPress data (users, posts, settings). It is only accessible from the internal Docker network, never exposed to the outside.
- Sensitive credentials (passwords) are managed via **Docker Secrets** rather than plain environment variables.
- Data is persisted through **bind mount volumes** on the host machine, so it survives container restarts.

---

### Virtual Machines vs Docker

#### What is a Daemon?

A daemon is a program that runs in the background, often launched at startup with root privileges. As soon as it receives a specific command or request, it executes what it was programmed to do.

Examples: `cron`, `httpd`, `syslog`

#### Why is Docker Different from VMs?

Docker differs from VMs because it does not emulate hardware. It acts as a daemon that uses the host machine via isolated processes.

Its design relies on three Linux pillars:

- **Namespaces**: isolate the container and give it access only to its own resources. In the PID namespace, the first process launched **is truly PID1** in that isolated space (on the host machine it will have a different PID, but inside the container it is genuinely PID1 — this is not an illusion, it is real isolation).
- **Cgroups**: define how many resources are allocated to a process. If a process goes out of control, the OOM Killer (Out Of Memory Killer) can intervene.
- **PID1**: the parent process of all processes when an OS boots. Inside a container, the process launched by ENTRYPOINT/CMD becomes PID1.

---

### Secrets vs Environment Variables

| | Environment Variables | Docker Secrets |
|--|----------------------|----------------|
| Storage | In `.env` file or shell | In encrypted files under `/run/secrets/` |
| Visibility | Visible via `docker inspect` or `env` | Not visible from outside |
| Use case | Non-sensitive config (usernames, domain, db name) | Passwords and sensitive credentials |

In this project, non-sensitive values (`DOMAIN_NAME`, `MYSQL_USER`, `WP_USER`, etc.) are stored in `srcs/.env`. Passwords (`MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, `WP_PASSWORD`) are stored as Docker Secrets in `srcs/secrets/`.

---

### Docker Network vs Host Network

| | Docker Network (Bridge) | Host Network |
|--|------------------------|--------------|
| Isolation | Each container has its own private IP | Container shares the host's network stack |
| Port conflicts | Impossible between containers | Possible — container uses host ports directly |
| DNS | Internal Docker DNS resolves service names | No internal DNS |
| Security | Containers isolated from host network | No network isolation |

In this project, all containers communicate through a private **Docker bridge network** named `inception`. Only Nginx exposes port 443 to the outside via `ports:`. MariaDB and WordPress are never directly reachable from outside the Docker network.

---

### Docker Volumes vs Bind Mounts

| | Docker Volumes | Bind Mounts |
|--|---------------|-------------|
| Managed by | Docker | The user |
| Location | Docker internal storage | Any path on the host (`/home/user/data/...`) |
| Portability | High | Depends on the host path |
| Use case | Production, managed data | Development, direct host access |

In this project, **bind mounts** are used so that data is stored at a known location on the host machine:

```
/home/lpalabos/data/wordpress  ←→  /var/www/html  (WordPress files)
/home/lpalabos/data/mariadb    ←→  /var/lib/mysql (MariaDB data)
```

Data persists across `make down` / `make up` cycles because it lives on the host, not inside the containers.

> ⚠️ Only `make fclean` permanently deletes this data.

---

## Instructions

### Prerequisites

- A Linux OS
- [Docker Engine](https://docs.docker.com/engine/install/) or [Docker Desktop](https://docs.docker.com/desktop/)
- Make and Git:
```bash
sudo apt install make git
```

Verify your Docker installation:
```bash
docker run hello-world
```

### Setup

1. Clone the repository:
```bash
git clone https://github.com/LLePep/Docker.git <folder_name>
cd <folder_name>
```

2. Fill in `srcs/.env`:
```env
DOMAIN_NAME=lpalabos.42.fr
MYSQL_DATABASE=db_lpalabos
MYSQL_USER=          # MariaDB username
WP_TITLE=            # WordPress site title
WP_USER=             # WordPress admin login (must not contain "admin")
WP_EMAIL=            # WordPress admin email
```

3. Fill in the secret files **before** running `make`:
```
srcs/secrets/db_root_password.txt  → MariaDB root password
srcs/secrets/db_password.txt       → MariaDB user password
srcs/secrets/wp_password.txt       → WordPress admin password
```

> The WordPress admin login corresponds to `WP_USER` in `srcs/.env`.

### Run

```bash
make        # builds images and starts containers
make up     # restarts containers without rebuilding images
make down   # stops containers
make clean  # stops containers and removes images
make fclean # make clean + removes all volumes and data
make re     # rebuilds everything from scratch
```

> ⚠️ `make fclean` permanently destroys all WordPress and MariaDB data.

### Access the Website and Administration Panel

| Page | URL |
|------|-----|
| Website | https://lpalabos.42.fr |
| Admin panel | https://lpalabos.42.fr/wp-admin |

> The site uses TLS 1.2/1.3 with a self-signed certificate (not submitted to a CA).
> Your browser will display a security warning — click **"Advanced"** then **"Proceed"** to continue.

### Credentials

**WordPress admin login** → `WP_USER` in `srcs/.env`

**WordPress admin password** → `srcs/secrets/wp_password.txt`

### Check that the Infrastructure is Running

```bash
docker ps               # checks that all 3 containers are "Up"
docker logs nginx       # incoming request logs
docker logs wordpress   # PHP-FPM logs
docker logs mariadb     # database logs
```

If a container is in `Exited` state:
1. Check its logs to identify the error: `docker logs <container>`
2. Restart with `make re`

### Data Persistence

Project data is stored on the host machine and mounted into containers via bind volumes:

| Data | Host path | Container path |
|------|-----------|----------------|
| WordPress files | `/home/lpalabos/data/wordpress` | `/var/www/html` |
| MariaDB database | `/home/lpalabos/data/mariadb` | `/var/lib/mysql` |

Data persists across `make down` / `make up` cycles because it lives on the host, not inside the containers.

> ⚠️ Only `make fclean` permanently deletes this data.

---

## Resources

### Official Documentation
- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [WordPress CLI Documentation](https://wp-cli.org/)
- [MariaDB Documentation](https://mariadb.com/kb/en/)
- [PHP-FPM Documentation](https://www.php.net/manual/en/install.fpm.configuration.php)

### Articles & Tutorials
- [stephane.robert.info](https://stephane.robert.info) — Docker and infrastructure tutorials
- Default configuration file comments (MariaDB, PHP-FPM, Nginx) — used as primary reference for understanding each directive

### AI Usage
AI (Claude by Anthropic) was used throughout this project for the following tasks:
- **Debugging**: identifying the root cause of issues (redirect loops, container startup failures, volume permission problems).
- **Concept clarification**: understanding Docker internals (namespaces, cgroups, FastCGI, TLS handshake, PHP-FPM process management modes).
- **Configuration review**: verifying the correctness of Nginx, PHP-FPM and MariaDB configuration files.
- **Documentation**: structuring and writing the README and developer notes.

AI was not used to generate the core project code (Dockerfiles, configuration files, shell scripts) — these were written and understood independently.