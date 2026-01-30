# Run deployer wizard on OpenShift

## Log in to the OpenShift cluster
Log is as a cluster administrator to be able to run the deployer with the correct permissions.

## Prepare the deployer project and the storage
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block (exactly into the window)
``` { .yaml .copy }
---
apiVersion: v1
kind: Namespace
metadata:
  creationTimestamp: null
  name: cloud-pak-deployer
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloud-pak-deployer-sa
  namespace: cloud-pak-deployer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: system:openshift:scc:privileged
  namespace: cloud-pak-deployer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:openshift:scc:privileged
subjects:
- kind: ServiceAccount
  name: cloud-pak-deployer-sa
  namespace: cloud-pak-deployer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cloud-pak-deployer-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: cloud-pak-deployer-sa
  namespace: cloud-pak-deployer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cloud-pak-deployer-config
  namespace: cloud-pak-deployer
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cloud-pak-deployer-status
  namespace: cloud-pak-deployer
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
```

## Run the deployer wizard and expose route
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block (exactly into the window)
``` { .yaml .copy }
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloud-pak-deployer-wizard
  namespace: cloud-pak-deployer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloud-pak-deployer-wizard
  template:
    metadata:
      name: cloud-pak-deployer-wizard
      labels:
        app: cloud-pak-deployer-wizard
    spec:
      containers:
      - name: cloud-pak-deployer
        image: quay.io/cloud-pak-deployer/cloud-pak-deployer:latest
        imagePullPolicy: Always
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        ports:
        - containerPort: 8080
          protocol: TCP
        env:
        - name: CONFIG_DIR
          value: /Data/cpd-config
        - name: STATUS_DIR
          value: /Data/cpd-status
        - name: CPD_WIZARD_PAGE_TITLE
          value: "Cloud Pak Deployer"
#        - name: CPD_WIZARD_MODE
#          value: existing-ocp
        volumeMounts:
        - name: config-volume
          mountPath: /Data/cpd-config
        - name: status-volume
          mountPath: /Data/cpd-status
        command: ["/bin/sh","-xc"]
        args: 
          - mkdir -p /Data/cpd-config/config && /cloud-pak-deployer/cp-deploy.sh env wizard -v
      securityContext:
        runAsUser: 0
      serviceAccountName: cloud-pak-deployer-sa
      volumes:
      - name: config-volume
        persistentVolumeClaim:
          claimName: cloud-pak-deployer-config   
      - name: status-volume
        persistentVolumeClaim:
          claimName: cloud-pak-deployer-status        
---
apiVersion: v1
kind: Service
metadata:
  name: cloud-pak-deployer-wizard-svc
  namespace: cloud-pak-deployer    
spec:
  selector:                  
    app: cloud-pak-deployer-wizard
  ports:
  - nodePort: 0
    port: 8080            
    protocol: TCP
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: cloud-pak-deployer-wizard
spec:
  tls:
    termination: edge
  to:
    kind: Service
    name: cloud-pak-deployer-wizard-svc
    weight: null
```

## Open the wizard
Now you can access the deployer wizard using the route created in the `cloud-pak-deployer` project.
* Open the OpenShift console
* Go to Networking --> Routes
* Click the Cloud Pak Deployer wizard route