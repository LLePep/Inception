USERNAME := lpalabos

all: dir
	@echo "Running containers"
	docker compose --env-file 'srcs/.env' --project-directory 'srcs' -p inception42 up -d

dir:
	mkdir -p /home/$(USERNAME)/data/mariadb
	mkdir -p /home/$(USERNAME)/data/wordpress
	sed -i 's/^GIT_VERSION=.*/GIT_VERSION=$(shell git rev-parse --short HEAD)/' srcs/.env

up:
	docker compose --project-directory 'srcs' -p inception42 up -d

down:
	docker compose -p inception42 down

clean:
	@echo "Stopping containers and deleting images"
	docker compose --project-directory 'srcs' -p inception42 down --rmi all

fclean: clean
	@echo "Suppression of volumes"
	docker compose --project-directory 'srcs' -p inception42 down --volumes
	docker system prune -f
	sudo rm -rf /home/$(USERNAME)/data

re: fclean all

.PHONY: all dir down up clean fclean re