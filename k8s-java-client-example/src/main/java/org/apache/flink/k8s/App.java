package org.apache.flink.k8s;

import io.kubernetes.client.ApiClient;
import io.kubernetes.client.ApiException;
import io.kubernetes.client.Configuration;
import io.kubernetes.client.Exec;
import io.kubernetes.client.apis.CoreV1Api;
import io.kubernetes.client.models.V1Container;
import io.kubernetes.client.models.V1ContainerPort;
import io.kubernetes.client.models.V1EnvVar;
import io.kubernetes.client.models.V1ObjectMeta;
import io.kubernetes.client.models.V1Pod;
import io.kubernetes.client.models.V1PodList;
import io.kubernetes.client.models.V1PodSpec;
import io.kubernetes.client.util.Config;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Arrays;
import java.util.Collections;

public class App {
    public static void main(String[] args) throws IOException, ApiException{
        ApiClient client = Config.defaultClient();
        Configuration.setDefaultApiClient(client);
        CoreV1Api api = new CoreV1Api();

        // spinUpTM(api);
        listPods(api);
    }

    private static void listPods(CoreV1Api api) throws ApiException {
        V1PodList list = api.listPodForAllNamespaces(null, null, null, null, null, null, null, null, null);
        for (V1Pod item : list.getItems()) {
            System.out.println(item.getMetadata().getName());
        }
    }

    private static void spinUpTM(CoreV1Api api) throws ApiException {
        V1Container container = new V1Container()
                .name("taskmanager")
                .image("flink:native-kubernetes")
                .args(Collections.singletonList("taskmanager"))
                .ports(Arrays.asList(
                        new V1ContainerPort().name("data").containerPort(6121),
                        new V1ContainerPort().name("rpc").containerPort(6122),
                        new V1ContainerPort().name("query").containerPort(6125)
                ))
                .env(Collections.singletonList(new V1EnvVar().name("JOB_MANAGER_RPC_ADDRESS").value("flink-jobmanager")));
        V1Pod pod = new V1Pod()
                .apiVersion("v1")
                .metadata(new V1ObjectMeta().name("flink-taskmanager"))
                .spec(new V1PodSpec().containers(Collections.singletonList(container)));
        System.out.println("Before:");
        System.out.println(pod);
        pod = api.createNamespacedPod("default", pod, "true");
        System.out.println("After:");
        System.out.println(pod);
    }

//    private static void uploadFile(ApiClient client, V1Pod pod, String path) throws IOException, ApiException {
//        Exec exec = new Exec(client);
//        Process p = exec.exec(pod, new String[] {"tar", "xf", "-", "-C", "/"}, false);
//
//        TarArchiveEntry entry = new TarArchiveEntry(desFilePath);
//
//        try (TarArchiveOutputStream tarOut = new TarArchiveOutputStream(watch.getInput());
//             ByteArrayOutputStream byteOut = new ByteArrayOutputStream();) {
//
//            byte[] bytes = new byte[4096];
//            int count;
//            while ((count = inputStream.read(bytes)) > 0) {
//                byteOut.write(bytes, 0, count);
//            }
//
//            entry.setSize(byteOut.size());
//            tarOut.putArchiveEntry(entry);
//            byteOut.writeTo(tarOut);
//            tarOut.closeArchiveEntry();
//        }
//    }
}
