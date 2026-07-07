# Technical Notes — Inception

---

# Docker

## Alpine vs Debian

- **Alpine**: uses `musl` — lightweight, fast, security-oriented, less compatible.
- **Debian**: uses `glibc` — heavier, much more adaptable, optimized for modern projects.

For Inception, Debian is used because compatibility matters more than lightness.

---

## musl vs glibc

| | musl | glibc |
|--|------|-------|
| Size | Lightweight | Heavy |
| Compilation speed | Fast | Slower |
| Compatibility | Limited | Very broad |
| Use case | Lightweight/security projects | Modern complex projects |

---

## Distroless — Optimal Security

Distroless images (maintained by Google) embed only the strict minimum to run an application. No shell, no package manager, no superfluous tools.

The main challenge is the **multi-stage build**: multiple successive `FROM` instructions in the Dockerfile. The idea is to use a classic distribution to install all dependencies, then `COPY` them into the final Distroless image. Result: a tiny image that is very hard for an attacker to exploit.

---

## Dockerfile Best Practices

- Organize instructions from **least to most frequently changing** (what rarely changes goes at the top) to optimize build cache.
- Think in **layers**: each instruction creates a new layer.
- Use `--no-install-recommends` to avoid unnecessary packages.
- Use `.dockerignore` (same principle as `.gitignore`).
- Use `--no-cache` to force a clean build.
- Use `--pull` to force pulling the latest version of the base image.
- Aim for **ephemeral images**: a container should be destroyable and recreatable without data loss.

---

## Shell Form vs Exec Form

```dockerfile
INSTRUCTION command param1 param2            # shell form
INSTRUCTION ["executable","param1","param2"] # exec form
```

**Shell form**: executes via `/bin/sh -c`. The shell becomes PID1 and the application is PID2. If Docker sends a `SIGTERM`, `/bin/sh` does not propagate it → the application does not release its resources → Docker sends a brutal `SIGKILL`.

**Exec form**: the application is directly PID1, it receives system signals directly and can shut down cleanly. **Preferred for ENTRYPOINT and CMD.**

---

## Dockerfile Instructions

### FROM
Initializes a new build stage. Defines the base image.
In multi-stage builds, multiple `FROM` instructions can be used successively.

### RUN
Creates a layer during `docker build`. Prefer a single package manager call per `RUN` to minimize the number of layers.

### ENTRYPOINT && CMD
- **ENTRYPOINT**: defines the main command (rarely overridden, use `--entrypoint` option).
- **CMD**: defines the default arguments for the main command, easily overridable.
They work together.

### LABEL
Creates metadata inside the image. Accessible via `docker inspect <image>`.

### ENV
Defines environment variables inside the container. Overridable with `-e`. Persistent at runtime.

### ARG
Defines **build-time** variables only — they no longer exist at runtime.
⚠️ Never put sensitive data here: they remain visible in `docker history <image>`.
Key difference with ENV: ARG = only during build, ENV = available at runtime.

### COPY vs ADD
- `COPY <host-path> <image-path>`: simple copy from host to container.
- `ADD`: like COPY but also handles URLs and archive extraction.
- **Rule**: always prefer `COPY`, use `ADD` only when automatic extraction is needed.

### VOLUME
Creates a mount point. Three types:
- **Bind mount**: user specifies the path between their OS and the container.
- **Volume mount**: managed by Docker.
- **tmpfs mount**: temporary lifespan, data reset on stop/restart. Useful for sensitive temporary data (tokens, sessions) as it never touches the disk.
- **Named pipes**: communication between container and host, useful for CI/CD pipelines.

### WORKDIR
Sets the working directory during the build and at execution time.

### EXPOSE
**Purely documentary.** Does not actually open any port.
In a Docker bridge network, containers communicate with each other **without needing EXPOSE** — communication happens via the service name on any port without restriction.
The real port mapping is done with `-p` or `ports:` in docker-compose.

---

## Docker Volumes — Commands

```bash
docker volume create <name>   # create a volume
docker volume ls              # list volumes
docker volume rm <name>       # remove a volume
docker volume inspect <name>  # inspect a volume
docker volume prune           # remove all unused volumes

# Launch a container with a bind mount
docker run --rm -it -v <local_folder>:<container_folder> <image>

# Launch a container with a named volume
docker run --rm -it -v <volume_name>:<container_folder> <image>
```

⚠️ If using a Bind Mount for WordPress, remember to run `chown -R 33:33` on the host folder (www-data UID), otherwise WordPress won't be able to install plugins or upload images.

---

## Docker Networking

### The 3 Network Modes

| Mode | Description | Use case |
|------|-------------|----------|
| `none` | Total isolation, no network | Maximum security |
| `bridge` | Virtual private network with NAT | Standard use |
| `host` | Directly shares the host's network stack | ⚠️ Dangerous in production |

### Classic Bridge vs Docker Bridge

- **Classic network bridge**: connects two network interfaces at L2 (data link layer) to share traffic between them.
- **Docker bridge**: creates an isolated virtual subnet with NAT (Network Address Translation). Each container has its own private IP address. Docker provides an internal DNS to resolve service names (e.g. `mariadb`, `wordpress`). Built on Linux **Network Namespaces**.

### Host Network
The container shares **the host's network stack** (not processes, which remain isolated). The container directly uses the host machine's network interfaces and ports → risk of port conflicts.

### Port Mapping
```bash
docker run -p <host_port>:<container_port> <image>
```

---

## Docker Compose

A file that orchestrates multiple containers, their dependencies, networks and volumes to deliver an operational infrastructure. Readable and quick to understand once opened.

### Watchtower
A tool that monitors running containers and **automatically updates them** when a new version of their image is available on the registry. Useful for CD (Continuous Deployment).

---

# MariaDB Configuration File

## File Structure

MariaDB splits its configuration into several sections for historical compatibility reasons:

| Section | Read by |
|---------|---------|
| `[mysqld]` | The MariaDB daemon only |
| `[server]` | The server + integrated tools (e.g. Galera) |
| `[mysql]` | The connection client |
| `[mariadbd]` | Equivalent of `[mysqld]` but specific to MariaDB (not MySQL) |
| `[embedded]` | For the engine embedded inside another application (rare) |
| `[mariadb-11.8]` | Options specific to a precise version |

---

## Base Directives

### `user = mysql`
Once MariaDB finishes starting, it downgrades its privileges and takes on the identity of the `mysql` system user (very limited rights).

### `pid-file = /var/run/mysqld/mysqld.pid`
MariaDB writes its PID to this file at startup. Allows the system or Docker to know if the process is still alive.

### `datadir = /var/lib/mysql`
Physical location where MariaDB stores real data: WordPress tables, users, articles, passwords.

### `tmpdir = /tmp`
Folder for temporary files (intermediate calculations). Deleted as soon as the query is finished.

### `skip-name-resolve`
Docker does not handle Reverse DNS (IP → Name). Without this directive, MariaDB attempts a reverse DNS lookup on every connection and waits for a timeout. `skip-name-resolve` skips this useless check and eliminates connection wait times.

### `bind-address = 0.0.0.0`
Defaults to `127.0.0.1` (localhost only). In Docker, IPs are dynamic so a fixed IP cannot be written in the config. `0.0.0.0` = listen on all available network interfaces → WordPress can reach MariaDB from its container.

---

## Resource Management

| Directive | Role |
|-----------|------|
| `key_buffer_size = 128M` | RAM for MyISAM indexes (WordPress uses InnoDB, so rarely useful) |
| `max_allowed_packet = 1G` | Max size of a single SQL query (avoids "MySQL server has gone away" on large imports) |
| `thread_stack = 192K` | Working memory allocated per thread (standard Debian value) |
| `thread_cache_size = 8` | Keeps 8 threads on standby instead of destroying/recreating them on each request |
| `myisam_recover_options = BACKUP` | Auto-repair corrupted MyISAM tables after a crash, with a backup beforehand |
| `max_connections = 100` | Fuse: max 100 simultaneous clients, prevents MariaDB from consuming all RAM |
| `table_open_cache = 64` | Keeps 64 tables "open" in memory to avoid repeated disk accesses |

---

## Logs

```ini
# General log (WARNING: performance killer, only for short debug sessions)
general_log_file = /var/log/mysql/mysql.log
general_log      = 1

# Error log
log_error = /var/log/mysql/error.log

# Slow query log
log_slow_query_file = /var/log/mysql/mariadb-slow.log
log_slow_query_time = 10           # query considered slow if > 10s
log_slow_verbosity  = query_plan,explain  # detail the query execution plan
log-queries-not-using-indexes      # log if no index used (full table scan)
log_slow_min_examined_row_limit = 1000  # log if more than 1000 rows scanned
```

Log folder permissions:
```bash
mkdir -m 2750 /var/log/mysql
chown mysql /var/log/mysql
# 2750 : the "2" is SetGID (forces new files to inherit the group)
# 7 = rwx (user), 5 = r-x (group), 0 = --- (other)
```

---

## Replication and Scaling

```ini
server-id        = 1
log_bin          = /var/log/mysql/mysql-bin.log
expire_logs_days = 10
max_binlog_size  = 100M
```

Useful options for more advanced infrastructures with replication. Can be combined with **Galera** (clustering) and **MaxScale** (DB-side load balancer).

---

## SSL Inside Docker Network

Not necessary in our case. Our containers are in a fully isolated and controlled private Docker network. Interception risk is zero. SSL/TLS between services only makes sense if traffic transits over the Internet (e.g. DB spread across distant datacenters).

---

## InnoDB

WordPress uses InnoDB (modern engine). The official recommendation is to allocate 80% of system RAM to the InnoDB buffer pool:
```ini
innodb_buffer_pool_size = 8G  # adjust based on available RAM
```

---

# PHP-FPM Configuration File (WordPress)

## Pool `[www]`

The `[www]` section creates a **pool** that dictates the behavior of the WordPress server. Pool isolation allows hosting multiple sites on the same server: if one crashes, it does not impact the others.

### User and Group
```ini
user  = www-data
group = www-data
```
Owner of the PHP-FPM process.

### Listen
```ini
listen = 0.0.0.0:9000
```
PHP-FPM listens on port 9000 to receive FastCGI requests from nginx.

### Backlog
```ini
listen.backlog = 511
```
Number of pending connections that can queue up. Value `-1` on BSD = unlimited.
⚠️ If modified, the Linux OS value AND the nginx value must also be adjusted, otherwise the change has no effect.

### Unix Socket Permissions — ACL
```ini
listen.acl_users  = www-data
listen.acl_groups = www-data
```
ACLs (Access Control Lists) are more flexible than classic Unix permissions (1 user, 1 group, others). They allow granting rights to multiple users/groups without limitation.

> Classic Unix permissions are limited: 1 user, 1 group, others — with only r/w/x for each. ACLs fill this gap by allowing rights to be assigned to any user or group, without limitation.

⚠️ `listen.acl_users` only works with **Unix sockets**, not with TCP sockets (`0.0.0.0:9000`). Comment it out if listening on TCP.

### Niceness (Priority)
```ini
; process.priority = -19
```
From -19 (highest priority) to 20 (lowest priority). Not set by default.

### Process Dumpable
```ini
; process.dumpable = yes
```
Disabled by default. When PHP-FPM starts as root then switches to `www-data`, Linux locks memory dumping. This option re-enables it.
⚠️ Useful in dev for debugging, **absolutely avoid in production**.

---

## Process Management Modes

| Mode | Behavior | Use case |
|------|----------|----------|
| `static` | Fixed number of workers, always running | High continuous demand, max performance |
| `dynamic` | Creates/destroys workers based on demand | Medium infrastructures with variable traffic |
| `ondemand` | Creates workers only on demand, destroys them on absence | Small infrastructures, RAM saving |

```ini
pm = dynamic
pm.max_children      = 25  # max simultaneous workers
pm.start_servers     = 5   # workers at startup
pm.min_spare_servers = 1   # min idle workers
pm.max_spare_servers = 10  # max idle workers
```

### `clear_env = no`
By default PHP-FPM clears environment variables before passing them to workers. Setting to `no` allows container variables (like those from `.env`) to be accessible in PHP code via `getenv()`, `$_ENV`, `$_SERVER`.

---

# Nginx Configuration File

## General Structure

```nginx
server {
    # Main block: defines a virtual host
}
```

Nginx can host multiple sites on the same server via multiple `server` blocks. Each block responds to a different domain or port.

---

## Directives Explained

### Listen and Domain
```nginx
listen 443 ssl;
listen [::]:443 ssl;
server_name lpalabos.42.fr;
```
- `listen 443 ssl`: listens on port 443 in SSL/TLS mode (IPv4).
- `listen [::]:443 ssl`: same for IPv6.
- `server_name`: the domain this block responds to. If the request does not match, nginx ignores it.

---

### SSL/TLS
```nginx
ssl_certificate     /etc/nginx/ssl/nginx-selfsigned.crt;
ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;
ssl_protocols       TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:...';
```
- `ssl_certificate` / `ssl_certificate_key`: path to the certificate and its private key.
- `ssl_protocols`: allowed TLS versions. TLSv1.0 and TLSv1.1 are deprecated and disabled — only TLS 1.2 and 1.3 are allowed (Inception subject requirement).
- `ssl_prefer_server_ciphers on`: forces the use of the server's cipher suites rather than those proposed by the client.
- `ssl_ciphers`: list of allowed encryption algorithms. `ECDHE` = elliptic curve key exchange (Perfect Forward Secrecy), `AES-GCM` = fast and secure symmetric encryption.

---

### Root and Index
```nginx
root  /var/www/html;
index index.php index.html;
```
- `root`: root folder where nginx looks for files to serve. Corresponds to the mounted WordPress volume.
- `index`: files to serve by default if no file is specified in the URL. Nginx tries `index.php` first, then `index.html`.

---

### Location `/` — Static Files
```nginx
location / {
    try_files $uri $uri/ /index.php?$args;
}
```
- `try_files`: nginx first looks for the exact file (`$uri`), then the directory (`$uri/`), and if nothing is found it falls back to `index.php` with the arguments. This is what enables WordPress **clean URLs** (permalinks) without a visible `.php` extension.

---

### Location `~ \.php$` — FastCGI to PHP-FPM
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
- `location ~ \.php$`: intercepts all requests to a `.php` file (`~` indicates a regex).
- `fastcgi_split_path_info`: separates the PHP script path from the path info (useful for some WordPress configurations).
- `fastcgi_pass wordpress:9000`: sends the request to the WordPress container on port 9000 via the FastCGI protocol. `wordpress` is resolved by Docker's internal DNS.
- `include fastcgi_params`: loads the standard FastCGI variables (HTTP method, query string, etc.).
- `fastcgi_param SCRIPT_FILENAME`: tells PHP-FPM which file to execute. `$document_root` = `/var/www/html`, `$fastcgi_script_name` = the requested `.php` file.
- `fastcgi_param HTTPS on`: tells WordPress we are in HTTPS. Without this line, WordPress detects HTTP and redirects → infinite redirect loop.