``` { .yaml .copy }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloud-pak-deployer-config
  namespace: cloud-pak-deployer
data:
  cpd-config.yaml: |
    {% include '../../../../sample-configurations/sample-dynamic/config-samples/ocp-existing-ocp-auto.yaml' %}

    {% include '../../../../sample-configurations/sample-dynamic/config-samples/cp4i-latest.yaml' %}
```
