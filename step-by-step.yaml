1. pull helm template

    helm pull prometheus-community/kube-prometheus-stack --untar

2. configure custom_values.yaml
3. apply

    helm install prometheus . \
        --namespace monitoring \
        -f custom_values.yaml
4. result

    NAME: prometheus
    LAST DEPLOYED: Fri Jun 13 11:45:00 2025
    NAMESPACE: monitoring
    STATUS: deployed
    REVISION: 1
    NOTES:
    kube-prometheus-stack has been installed. Check its status by running:
      kubectl --namespace monitoring get pods -l "release=prometheus"

    Get Grafana 'admin' user password by running:

      kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

    Access Grafana local instance:

      export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus" -oname)
      kubectl --namespace monitoring port-forward $POD_NAME 3000

    Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.

5. access grafana

    kubectl port-forward svc/prometheus-grafana 3000:80 --namespace monitoring

6. build application -- check GOARCH=amd64

    docker build -t asia-southeast1-docker.pkg.dev/devops-docker-demo-458213/golang-prometheus-metrics/golang-prometheus-metrics:v1.0.0 .

7. push application

    docker push asia-southeast1-docker.pkg.dev/devops-docker-demo-458213/golang-prometheus-metrics/golang-prometheus-metrics:v1.0.0

8. create deployment and service
9. create serviceMonitor
10. install elasticsearch -- beware of initialDelaySeconds (10s -> 200s)

    NAME: elasticsearch
    LAST DEPLOYED: Fri Jun 13 13:40:02 2025
    NAMESPACE: monitoring
    STATUS: deployed
    REVISION: 1
    NOTES:
    1. Watch all cluster members come up.
      $ kubectl get pods --namespace=monitoring -l app=elasticsearch-master -w
    2. Retrieve elastic user's password.
      $ kubectl get secrets --namespace=monitoring elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d
    3. Test cluster health using Helm test.
      $ helm --namespace=monitoring test elasticsearch

11. password elasticsearch-master-credentials - 5dxoVxhswzMyn6i1
12. install kibana

    NAME: kibana
    LAST DEPLOYED: Fri Jun 13 14:18:18 2025
    NAMESPACE: monitoring
    STATUS: deployed
    REVISION: 1
    TEST SUITE: None
    NOTES:
    1. Watch all containers come up.
      $ kubectl get pods --namespace=monitoring -l release=kibana -w
    2. Retrieve the elastic user's password.
      $ kubectl get secrets --namespace=monitoring elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d
    3. Retrieve the kibana service account token.
      $ kubectl get secrets --namespace=monitoring kibana-kibana-es-token -ojsonpath='{.data.token}' | base64 -d

13. install logstash -- change password elasticsearch

    NAME: logstash
    LAST DEPLOYED: Fri Jun 13 15:42:22 2025
    NAMESPACE: monitoring
    STATUS: deployed
    REVISION: 1
    TEST SUITE: None
    NOTES:
    1. Watch all cluster members come up.
      $ kubectl get pods --namespace=monitoring -l app=logstash-logstash -w

14. install filebeat

    NAME: filebeat
    LAST DEPLOYED: Fri Jun 13 16:08:36 2025
    NAMESPACE: logging
    STATUS: deployed
    REVISION: 1
    TEST SUITE: None
    NOTES:
    1. Watch all containers come up.
      $ kubectl get pods --namespace=logging -l app=filebeat-filebeat -w
