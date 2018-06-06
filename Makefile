flink_dir ?= ../flink
image_name ?= flink:native-kubernetes

minikube-start:
	minikube start
	$(MAKE) docker-registry

minikube-stop:
	minikube stop

minikube-ip:
	minikube ip

docker-registry:
	eval $(minikube docker-env)

flink-build:
	cd ..; mvn clean package -DskipTests

docker-build:
	cd $(flink_dir)/flink-contrib/docker-flink; \
		./build.sh --from-local-dist --image-name $(image_name)

flink-start:
	kubectl create -f conf/jobmanager-deployment.yaml
	#kubectl create -f conf/taskmanager-deployment.yaml
	kubectl create -f conf/jobmanager-service.yaml

flink-stop:
	kubectl delete -f conf/jobmanager-deployment.yaml
	kubectl delete -f conf/jobmanager-service.yaml
	#kubectl delete -f conf/taskmanager-deployment.yaml
