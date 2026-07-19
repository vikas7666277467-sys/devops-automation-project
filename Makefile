build:
	docker build -t devops-automation-project ./docker

run:
	docker run -d -p 8080:80 --name automation-demo devops-automation-project

stop:
	docker stop automation-demo
	docker rm automation-demo

deploy: build run

clean:
	docker system prune -f

status:
	docker ps