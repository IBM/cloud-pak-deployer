# Running deployer wizard as a pod for existing OpenShift cluster

## Collect cluster credentials
* Cluster: ...
* OpenShift admin user: `kubeadmin`
* Password: ...

## Login to cluster
```
oc login ... --insecure-skip-tls-verify
```

## Prepare the deployer project
```
oc new-project cloud-pak-deployer 

oc project cloud-pak-deployer
oc create serviceaccount cloud-pak-deployer-sa
oc adm policy add-scc-to-user privileged -z cloud-pak-deployer-sa
oc adm policy add-cluster-role-to-user cluster-admin -z cloud-pak-deployer-sa
```

## Build deployer image and push to the internal registry
Building the deployer image typically takes ~5 minutes. Only do this if the image has not been built yet.

```
if ! oc get istag -n cloud-pak-deployer cloud-pak-deployer:latest --no-headers 2> /dev/null;then 

cat << EOF | oc apply -f -
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: cloud-pak-deployer
spec:
  lookupPolicy:
    local: true
EOF

cat << EOF | oc apply -f -
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: cloud-pak-deployer-bc
  namespace: cloud-pak-deployer
spec:
  source:
    type: Git
    git:
      uri: https://github.com/IBM/cloud-pak-deployer
      ref: ui
  strategy:
    type: Docker                      
  output:
    to:
      kind: ImageStreamTag
      name: cloud-pak-deployer:latest
EOF

  oc delete build -n cloud-pak-deployer -l buildconfig=cloud-pak-deployer-bc
  oc start-build -n cloud-pak-deployer bc/cloud-pak-deployer-bc

echo "Wait for image to be built and pushed to internal registry..."
while ! oc get istag -n cloud-pak-deployer cloud-pak-deployer:latest 2>/dev/null;do
  sleep 1
done

fi
```

## Start the deployer wizard pod
```
export DEPLOYER_SC=managed-nfs-storage

cat << EOF | oc apply -f -
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
      storage: 10Gi
  storageClassName: $DEPLOYER_SC
EOF

cat << EOF | oc apply -f -
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
  storageClassName: $DEPLOYER_SC
EOF

cat << EOF | oc apply -f -
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
        image: cloud-pak-deployer:latest
        imagePullPolicy: Always
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        ports:
        - containerPort: 32080
          protocol: TCP
        env:
        - name: CONFIG_DIR
          value: /Data/cpd-config
        - name: STATUS_DIR
          value: /Data/cpd-status
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
EOF
```

## Expose the service and create the route
```
cat << EOF | oc apply -f -
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
    port: 32080            
    protocol: TCP
EOF

cat << EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: cloud-pak-deployer-wizard-svc
  namespace: cloud-pak-deployer
spec:
  port:
    targetPort: 32080
  to:
    kind: Service
    name: cloud-pak-deployer-wizard-svc
    weight: 100
EOF
```

