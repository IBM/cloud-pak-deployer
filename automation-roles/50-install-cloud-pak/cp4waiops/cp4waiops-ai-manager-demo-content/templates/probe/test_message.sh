export WAIOPS_NAMESPACE=$(oc get po -A|grep aiops-orchestrator-controller |awk '{print$1}')
export PROBE_WEBHOOK_URL="https://"$(oc get routes generic-probe-mb-webhook -n $WAIOPS_NAMESPACE -o=jsonpath='{.status.ingress[0].host}{"\n"}')"/probe"
echo "$PROBE_WEBHOOK_URL"


## WEBHOOK PROBE TEST
curl -X "POST" "$PROBE_WEBHOOK_URL" \
     -H 'Content-Type: text/plain; charset=utf-8' \
     -H 'Cookie: 8a3ca3e7036a020dcf1e98075251e2b8=6b0d31808967c487642156d942be194f' \
     -u 'administrator:{{global_config.global_password}}' \
     -d $'{
    "id": "1a2a6787-59ad-4acd-bd0d-46c1ddfd8e00",
    "occurrenceTime": "MY_TIMESTAMP",
    "summary": "TEST MESSAGE FROM WEBHOOK",
    "actionType": "test",
    "severity": "CRITICAL",
    "type": {
        "eventType": "problem",
        "classification": "Webhook Probe"
    },
    "expirySeconds": 6000000,
    "links": [{
        "linkType": "webpage",
        "name": "GitHub",
        "description": "GitHub",
        "url": "https://pirsoscom.github.io/git-commit-robot.html"
    }],
    "sender": {
        "type": "host",
        "name": "Test",
        "sourceId": "test"
    },
    "resource": {
        "type": "host",
        "name": "robot-shop",
        "sourceId": "kubernetes"
    },
    "details": {
        "operation": "push",
        "user": "nikh@ch.ibm.com",
        "branch": "main"
    }
}
'
