# Run deployer wizard on OpenShift

## Log in to the OpenShift cluster
Log is as a cluster administrator to be able to run the deployer with the correct permissions.

## Prepare the deployer project
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block (exactly) into the window
???+ note "Prepare the deployer project"
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
    ```

## Start the deployer
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block into the window. You can update the image on line 11 and the same value will be used for image for the Deployer Job

???+ note "Start the deployer wizard"
    ``` { .yaml .copy linenums="1" hl_lines="11" }
    apiVersion: v1
    kind: Pod
    metadata:
      labels:
        app: cloud-pak-deployer-start
      generateName: cloud-pak-deployer-start-
      namespace: cloud-pak-deployer
    spec:
      containers:
      - name: cloud-pak-deployer
        image: quay.io/cloud-pak-deployer/cloud-pak-deployer:latest
        imagePullPolicy: Always
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        command: ["/bin/sh","-xc"]
        args: 
          - /cloud-pak-deployer/scripts/deployer/cpd-start-deployer.sh --wizard
        envFrom:
        - configMapRef:
            name: cloud-pak-deployer-env
            optional: true
      restartPolicy: Never
      securityContext:
        runAsUser: 0
      serviceAccountName: cloud-pak-deployer-sa
    ```

## Open the wizard

Once the start pod finishes, you can access the deployer wizard using the route created in the `cloud-pak-deployer` project.

* Open the OpenShift console
* Go to Networking --> Routes
* Click the Cloud Pak Deployer `wizard` route
* Log in using your OpenShift cluster admin credentials (typically `kubeadmin`)
* Accept the information that will be shared with Cloud Pak Deployer