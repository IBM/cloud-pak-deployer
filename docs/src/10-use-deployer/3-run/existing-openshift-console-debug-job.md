## Start the deployer debug job only
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block into the window. You can update the image on line 11 and the same value will be used for image for the Deployer Job (From release v3.0.2 onwards).

???+ note "Start the deployer debug job"
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
          - /cloud-pak-deployer/scripts/deployer/cpd-start-deployer.sh --debug-only
      restartPolicy: Never
      securityContext:
        runAsUser: 0
      serviceAccountName: cloud-pak-deployer-sa
    ```