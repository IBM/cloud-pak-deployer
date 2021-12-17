#!/bin/sh

# VPC_REGION=us-east

# export IAM_TOKEN=$(ibmcloud iam oauth-tokens --output json | jq -r '.iam_token')
# export RESOURCE_GROUP=$(ibmcloud target --output json | jq -r '.resource_group.guid')
# export CLUSTER="${1}"
export UNIQUE_ID="px-roks" # Obtained from main.tf in terraform/cp4data
# ibmcloud target -r $VPC_REGION

usage()
{
    echo "usage: " `basename $0` "[-h] -r REGION -c CLUSTER"
    echo
    echo "Run remove volume attachment script."
    echo
    echo "arguments:"
    echo "  -h, --help            show this help message and exit"
    echo "  -r REGION, --region REGION"
    echo "                        Region the resources are located"
    echo "  -c CLUSTER, --cluster CLUSTER"
    echo "                        Cluster name"
    exit 1
}

if [ -z "$1" ]
  then
    usage
fi

while [ "$1" != "" ]; do
    case $1 in
        -r | --region )         shift
                                  VPC_REGION=$1
                                  ;;
        -c | --cluster )        shift
                                  CLUSTER=$1
                                  ;;                  
        -h | --help )             usage
                                  ;;
        * )                       usage
                                  ;;
    esac
    shift
done

ibmcloud target -r $VPC_REGION

echo "Removing attachment from worker-node"
for worker_node_id in `ibmcloud oc workers  --cluster $CLUSTER |grep '^kube' | cut -d ' ' -f 1` ; do 

    attachment_id=`ibmcloud ks storage attachments -c $CLUSTER -w ${worker_node_id} | grep ${UNIQUE_ID} | cut -d ' ' -f 1`
    ibmcloud ks storage attachment rm -c $CLUSTER -w ${worker_node_id} --attachment ${attachment_id}

done

# echo "sleeping 5"
# sleep 5

# echo "Removing storage"
# for volume_id in `ibmcloud is volumes | grep ${UNIQUE_ID} | cut -d ' ' -f 1` ; do

#     ibmcloud is volume-delete ${volume_id} -f

# done
