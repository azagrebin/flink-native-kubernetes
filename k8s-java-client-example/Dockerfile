FROM openjdk:8

# Install build dependencies and flink
# ADD config /root/.kube/config

# ADD kconf/ca.crt /root/.minikube/ca.crt
# ADD kconf/client.crt /root/.minikube/client.crt
# ADD kconf/client.key /root/.minikube/client.key

ADD target/k8s-java-client-example-1.0-SNAPSHOT.jar .

#CMD exec java -jar "./k8s-java-client-example-1.0-SNAPSHOT.jar"
CMD exec sleep 10000000