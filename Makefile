flink_dir ?= ../flink
image ?= flink
tag ?= native-kubernetes
image_name ?= $(image):$(tag)
job_jar ?= $(flink_dir)/flink-examples/flink-examples-streaming/target/WindowJoin.jar
flink_port ?= 8081
flink_cli ?= $(flink_dir)/build-target/bin/flink

helm_name ?= flink-native-kubernetes

browser ?= open -a "Google Chrome"

DOCKER_ID_USER = azagrebin
docker_cloud_image ?= $(DOCKER_ID_USER)/$(image)
docker_cloud_image_name ?= $(DOCKER_ID_USER)/$(image_name)

flink-build:
	cd $(flink_dir); \
		git co nativeKubernetes \
		mvn install -pl flink-core,flink-runtime,flink-clients,flink-kubernetes,flink-dist -DskipTests

docker-build:
	cd $(flink_dir)/flink-contrib/docker-flink-session; \
		./build.sh --from-local-dist \
		--image-name $(image_name) \
		--kubernetes-certificates ~/.minikube

docker-cloud-push: docker-build
	docker tag $(image_name) $(docker_cloud_image_name)
	docker push $(docker_cloud_image_name)

flink-start:
	helm install --name $(helm_name) --set image=$(docker_cloud_image) --set imageTag=$(tag) ./helm
	kubectl get --watch service

flink-stop:
	helm delete --purge $(helm_name)

flink-ip:
	@kubectl get service flink-native-kubernetes-session-cluster --output=json | jq -r .status.loadBalancer.ingress[0].ip

flink-ui:
	$(eval ip ?= $(shell make flink-ip))
	$(browser) http://$(ip):$(flink_port)

job-run:
	$(eval ip ?= $(shell make flink-ip))
	$(flink_cli) run -p 3 -m $(ip):$(flink_port) $(job_jar)

job-run-attached:
	$(flink_cli) run -m k8s --image azagrebin/flink-job:native-kubernetes $(job_jar)

job-run-detached:
	$(flink_cli) run -d -m k8s --userCodeJar http://people.apache.org/~trohrmann/WindowJoin.jar \
		--image azagrebin/flink-job:native-kubernetes \
		$(flink_dir)/flink-examples/flink-examples-streaming/target/WindowJoin.jar

cleanup:
	kubectl delete pod -l app=flink
	kubectl delete service -l app=flink

kubectl-install:
	brew install kubernetes-cli kubernetes-helm

kubectl-default-admin:
	kubectl create rolebinding add-on-admin --clusterrole=admin  --serviceaccount=default:default

# minikube

minikube-install: kubectl-install
	# https://kubernetes.io/docs/getting-started-guides/minikube/
	# https://github.com/kubernetes/minikube
	# VT-x or AMD-v virtualization must be enabled in your computer’s BIOS
	brew cask install virtualbox

	curl -LO https://storage.googleapis.com/minikube/releases/latest/docker-machine-driver-hyperkit \
	&& chmod +x docker-machine-driver-hyperkit \
	&& sudo mv docker-machine-driver-hyperkit /usr/local/bin/ \
	&& sudo chown root:wheel /usr/local/bin/docker-machine-driver-hyperkit \
	&& sudo chmod u+s /usr/local/bin/docker-machine-driver-hyperkit

	brew install docker-machine-driver-xhyve
	sudo chown root:wheel $(brew --prefix)/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve
	sudo chmod u+s $(brew --prefix)/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyv

	brew cask install minikube

# eval $(minikube docker-env) - run manually

minikube-start:
	minikube start
	minikube ssh 'sudo ip link set docker0 promisc on'
	$(MAKE) minikube-kubectl

minikube-kubectl:
	kubectl config use-context minikube

minikube-stop:
	minikube stop

minikube-ip:
	minikube ip

minikube-job-run:
	$(eval mip ?= $(shell minikube ip))
	$(flink_cli) run -p 1 -m $(mip):$(flink_port) $(job_jar)

minikube-flink-ui:
	$(eval mip ?= $(shell minikube ip))
	$(browser) http://$(mip):30081

# gke

gke_project ?= astral-sorter-757
gke_zone ?= europe-west1-b
gke_cluster_name ?= native-kubernetes
gke_version ?= 1.10.2-gke.3
gke_node_type ?= n1-standard-2
gke_node_num ?= 3
gke_image ?= gcr.io/$(gke_project)/$(image)
gke_image_name ?= gcr.io/$(gke_project)/$(image):$(tag)

gke-kubectl:
	gcloud container clusters get-credentials $(gke_cluster_name) --zone=$(gke_zone)

gke-cluster-create:
	gcloud container clusters create $(gke_cluster_name) \
		--cluster-version $(gke_version) \
		--zone $(gke_zone) \
		--machine-type $(gke_node_type) \
		--num-nodes $(gke_node_num)
	$(MAKE) gke-kubectl gke-kubectl-default-admin gke-helm

gke-helm:
	helm init
	$(eval password ?= $(shell make gke-cluster-password))
	kubectl --username=admin --password=$(password) create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
	kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

gke-kubectl-default-admin:
	$(eval password ?= $(shell make gke-cluster-password))
	kubectl --username=admin --password=$(password) \
		 create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin  --serviceaccount=default:default

gke-cluster-scale-down:
	gke_node_num=0 make gke-cluster-scale

gke-cluster-scale:
	gcloud container clusters resize $(gke_cluster_name) --zone $(gke_zone) --async \
		--size=$(gke_node_num)

gke-cluster-delete:
	gcloud container clusters delete $(gke_cluster_name) --zone $(gke_zone) --async

gke-cluster-password:
	@gcloud container clusters describe native-kubernetes --zone europe-west1-b --format=json | jq .masterAuth.password

gke-docker-config:
	gcloud auth configure-docker

gke-docker-push:
	docker tag $(image_name) $(gke_image_name)
	docker push $(gke_image_name)

gke-docker: flink-build docker-build gke-docker-push