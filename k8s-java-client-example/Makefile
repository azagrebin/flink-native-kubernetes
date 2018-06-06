name ?= k8s-java-client-example

build:
	mvn clean package

run: build
	java -jar target/$(name)-1.0-SNAPSHOT.jar

docker-run: build docker-build
	docker run --name $(name) $(name):native-kubernetes

docker-stop:
	docker rm k8s-java-client-example

# eval $(minikube docker-env)

docker-build: build
	# mkdir -p kconf
	# cp ~/.minikube/ca.crt kconf/.
	# cp ~/.minikube/client.crt kconf/.
	# cp ~/.minikube/client.key kconf/.
	docker build --no-cache -t $(name):native-kubernetes .

deploy: docker-build
	kubectl create -f $(name)-pod.yaml

stop:
	kubectl delete -f $(name)-pod.yaml

bash:
	kubectl exec -it k8s-java-client-example-pod -- /bin/bash