

https://github.com/instana/otel-shop/tree/master/K8s/charts/otel-shop


```bash
helm template otel-shop otel-shop \
    --create-namespace  \
    --namespace otel-shop \
    --set psp.enabled=true \
    --set eum.key=os3KrF7QQTe3AI3hefypRQ \
    --set eum.url=http://159.122.143.166:2999/ \
    --set openshift=true \
    --set ocCreateRoute=true
```



apiVersion: v1
kind: ResourceQuota
metadata:
  name: otel-shop-quota
spec:
  hard:
    limits.cpu: 4
    requests.cpu: 2
    limits.memory: 5Gi
    requests.memory: 3Gi
    pods: 20


oc create clusterrolebinding otel-shop-default-admin --clusterrole=cluster-admin --serviceaccount=otel-shoph:default
