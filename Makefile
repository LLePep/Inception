USERNAME := lpalabos

all: dir
	@echo "Running containers"
	docker compose --env-file 'srcs/.env' --project-directory 'srcs' -p inception42 up -d

dir:
	mkdir -p /home/$(USERNAME)/data/mariadb
	mkdir -p /home/$(USERNAME)/data/wordpress

clean:
	@echo "Stopping containers and deleting images"
	docker compose --project-directory 'srcs/' -p inception42 down --rmi all

fclean: clean
	@echo "Suppression of volumes"
	docker system prune --volumes
	sudo rm -rf /home/$(USERNAME)/data

re: fclean all

.PHONY: all dir clean fclean re