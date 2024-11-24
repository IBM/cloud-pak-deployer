---
title: Access NFS server provisioned on IBM Cloud
---

# Access NFS server provisioned on IBM Cloud
When choosing the "simple" sample configuration for ROKS VPC on IBM Cloud, the deployer also provisions a Virtual Server Instance and installs a standard NFS server on it. In some cases you may want to get access to the NFS server for troubleshooting.

For security reasons, the NFS server can only be reached via a bastion server that is connected to the internet, i.e. use the bastion server as a jump host, this to avoid exposing NFS volumes to the outside world and provide an extra layer of protection. Additionally, password login is disabled on both the bastion and NFS servers and one must use the private SSH key to connect.

## Start the command line within the container
Getting SSH access to the NFS server is easiest from within the deployer container as it has all tools installed to extract the IP addresses from the Terraform state file.

Optional: Ensure that the environment variables for the configuration and status directories are set. If not specified, the directories are assumed to be `$HOME/cpd-config` and `$HOME/cpd-status`.
``` { .bash .copy }
export STATUS_DIR=$HOME/cpd-status
export CONFIG_DIR=$HOME/cpd-config
```

Start the deployer command line.
``` { .bash .copy }
./cp-deploy.sh env command
```

```output
-------------------------------------------------------------------------------
Entering Cloud Pak Deployer command line in a container.
Use the "exit" command to leave the container and return to the hosting server.
-------------------------------------------------------------------------------
Installing OpenShift client
Current OpenShift context: pluto-01
```

## Obtain private SSH key
Access to both the bastion and NFS servers are typically protected by the same SSH key, which is stored in the vault. To list all vault secrets, run the command below.

``` { .bash .copy }
cd /cloud-pak-deployer
./cp-deploy.sh vault list
```

```output
./cp-deploy.sh vault list

Starting Automation script...

PLAY [Secrets] *****************************************************************
Secret list for group sample:
- ibm_cp_entitlement_key
- sample-terraform-tfstate
- cp4d_admin_zen_40_fke34d
- sample-all-config
- pluto-01-provision-ssh-key
- pluto-01-provision-ssh-pub-key

PLAY RECAP *********************************************************************
localhost                  : ok=11   changed=0    unreachable=0    failed=0    skipped=21   rescued=0    ignored=0
```

Then, retrieve the private key (in the above example `pluto-01-provision-ssh-key`) to an output file in your `~/.ssh` directory, make sure it has the correct private key format (new line at the end) and permissions (600).
``` { .bash .copy }
SSH_FILE=~/.ssh/pluto-01-rsa
mkdir -p ~/.ssh
chmod 600 ~/.ssh
./cp-deploy.sh vault get -vs pluto-01-provision-ssh-key \
    -vsf $SSH_FILE
echo -e "\n" >> $SSH_FILE
chmod 600 $SSH_FILE
```


## Find the IP addresses
To connect to the NFS server, you need the public IP address of the bastion server and the private IP address of the NFS server. Obviously these can be retrieved from the IBM Cloud resource list (https://cloud.ibm.com/resources), but they are also kept in the Terraform "tfstate" file

``` { .bash .copy }
./cp-deploy.sh vault get -vs sample-terraform-tfstate \
    -vsf /tmp/sample-terraform-tfstate
```

The below commands do not provide the prettiest output but you should be able to extract the IP addresses from them.

For the bastion node public (floating) IP address:
``` { .bash .copy }
cat /tmp/sample-terraform-tfstate | jq -r '.resources[]' | grep -A 10 -E "ibm_is_float"
```

```output
  "type": "ibm_is_floating_ip",
  "name": "pluto_01_bastion",
  "provider": "provider[\"registry.terraform.io/ibm-cloud/ibm\"]",
  "instances": [
    {
      "schema_version": 0,
      "attributes": {
        "address": "149.81.215.172",
...
        "name": "pluto-01-bastion",
```

For the NFS server:
``` { .bash .copy }
cat /tmp/sample-terraform-tfstate | jq -r '.resources[]' | grep -A 10 -E "ibm_is_instance|primary_network_interface"
```

```output
...
--
  "type": "ibm_is_instance",
  "name": "pluto_01_nfs",
  "provider": "provider[\"registry.terraform.io/ibm-cloud/ibm\"]",
  "instances": [
...
--
        "primary_network_interface": [
...
            "name": "pluto-01-nfs-nic",
            "port_speed": 0,
            "primary_ipv4_address": "10.227.0.138",
```

In the above examples, the IP addresses are:

* Bastion public IP address: `149.81.215.172`
* NFS server private IP address: `10.227.0.138`

## SSH to the NFS server
Finally, to get command line access to the NFS server:
``` { .bash .copy }
BASTION_IP=149.81.215.172
NFS_IP=10.227.0.138
ssh -i $SSH_FILE \
  -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i $SSH_FILE -W %h:%p -q $BASTION_IP" \
  root@$NFS_IP
```

## Stopping the session
Once you've finished exploring the NFS server, you can exit from it:
``` { .bash .copy }
exit
```

Finally, exit from the deployer container which is then terminated.
``` { .bash .copy }
exit
```