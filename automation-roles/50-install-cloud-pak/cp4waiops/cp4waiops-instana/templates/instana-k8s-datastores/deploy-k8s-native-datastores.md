# Deploy Kubernetes Native Datastores

This document will deploy the Instana datastores traditionally on a dedicated Virtual Machine deployed using Kubernetes native deployments. It relies on the Instana images from the Docker based installation. This is **not** a supported configuration by Instana and should only be used for a small PoC. This document also does not cater for any specific sizing.

Create the `instana-datastores` Project
```
$ oc new-project instana-datastores
```

If you need to set a default Node Selector for pods in this project, use the following command (ensure nodes are labelled with the same `node=instana-datastores`)
```
$ oc annotate ns instana-datastores openshift.io/node-selector='role=instana-datastores';
```

If you need to set a default Toleration for pods in this project, use the following command (ensure nodes are tainted with the matching taint `dedicated=instana-datastores:NoSchedule`)

```
oc annotate namespace instana-datastores scheduler.alpha.kubernetes.io/defaultTolerations='[{"Key": "dedicated", "Operator": "Equal", "Value": "instana-datastores","Effect": "NoSchedule"}]';
```

Create the ServiceAccount and ClusterRoleBinding

```
$ oc -n instana-datastores create -f common/datastores_sa.yaml
serviceaccount/instana-datastore-sa created

$ oc -n instana-datastores create -f common/datastores_crb.yaml
clusterrolebinding.rbac.authorization.k8s.io/instana-datastore-anyuid created
clusterrolebinding.rbac.authorization.k8s.io/instana-datastore-privileged created
```

Create a Secret containing your Instana agent or download key used to pull the container images from the Instana image repositories

```
$ oc create secret docker-registry instana-pullsecret --docker-server=containers.instana.io --docker-username="_" --docker-password=<agent-key> --docker-email=luca.floris@uk.ibm.com
secret/instana-pullsecret created
```

Link the secret to the default and  `instana-datastore-sa` Service Accounts
```
$ oc -n instana-datastores secrets link default instana-pullsecret --for=pull
$ oc -n instana-datastores secrets link instana-datastore-sa instana-pullsecret --for=pull
```

The above commands don't output any success message. You can check it was correctly added by using the following command and checking the `imagePullSecrets`

```
$ oc -n instana-datastores get sa instana-datastore-sa -o yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  creationTimestamp: "2022-06-01T14:01:29Z"
  name: instana-datastore-sa
  namespace: instana-datastores
  resourceVersion: "2111672230"
  uid: 91e14dcf-bcc0-4ecc-bd02-edba50b9d440
secrets:
- name: instana-datastore-sa-token-8sqld
- name: instana-datastore-sa-dockercfg-d4ngb
imagePullSecrets:
- name: instana-datastore-sa-dockercfg-d4ngb
- name: instana-pullsecret
```

Create all of the datastores, along with their respective PVCs and Services from the directories provided in this repo.

```
$ oc -n instana-datastores create -f ./zookeeper
deployment.apps/zookeeper created
persistentvolumeclaim/zookeeper-logs created
service/zookeeper-service created
$ oc -n instana-datastores create -f ./kafka
deployment.apps/kafka created
persistentvolumeclaim/kafka-logs created
persistentvolumeclaim/kafka-data created
service/kafka-service createdß
$ oc -n instana-datastores create -f ./clickhouse
deployment.apps/clickhouse created
persistentvolumeclaim/clickhouse-logs created
persistentvolumeclaim/clickhouse-data created
service/clickhouse-service created
$ oc -n instana-datastores create -f ./cockroachdb
deployment.apps/cockroachdb created
service/cockroachdb-service created
persistentvolumeclaim/cockroach-logs created
persistentvolumeclaim/cockroach-data created
$ oc -n instana-datastores create -f ./elasticsearch
deployment.apps/elasticsearch created
persistentvolumeclaim/es-data created
service/elasticsearch-service created
$ oc -n instana-datastores create -f ./cassandra
deployment.apps/cassandra created
persistentvolumeclaim/cassandra-data created
service/cassandra-service created
```

You can retrieve the service names and ports with the following

```
$ oc get svc
NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
cassandra-service       ClusterIP   172.30.69.145    <none>        9042/TCP            35s
clickhouse-service      ClusterIP   172.30.112.54    <none>        8123/TCP,9000/TCP   4m44s
cockroachdb-service     ClusterIP   172.30.4.160     <none>        26257/TCP           4m8s
elasticsearch-service   ClusterIP   172.30.111.243   <none>        9200/TCP,9300/TCP   52s
kafka-service           ClusterIP   172.30.85.129    <none>        9092/TCP            5m5s
zookeeper-service       ClusterIP   172.30.131.24    <none>        2181/TCP            13m
```

Use these cluster services in the Instana `Core` CR. For example, elasticsearch endpoint would be `elasticsearch-service.instana-datastores.svc.cluster.local`.