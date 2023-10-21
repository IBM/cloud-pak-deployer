# Create an Azure Service Principal

## Login to Azure
Login to the Microsoft Azure using your subscription-level credentials.
```
az login
```

If you have a subscription with multiple tenants, use:
```
az login --tenant <TENANT_ID>
```

Example:
```bash
az login --tenant 869930ac-17ee-4dda-bbad-7354c3e7629c8
To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code AXWFQQ5FJ to authenticate.
[
  {
    "cloudName": "AzureCloud",
    "homeTenantId": "869930ac-17ee-4dda-bbad-7354c3e7629c8",
    "id": "72281667-6d54-46cb-8423-792d7bcb1234",
    "isDefault": true,
    "managedByTenants": [],
    "name": "Azure Account",
    "state": "Enabled",
    "tenantId": "869930ac-17ee-4dda-bbad-7354c3e7629c8",
    "user": {
      "name": "your_user@domain.com",
      "type": "user"
    }
  }
]
```

## Set subscription (optional)

If you have multiple Azure subscriptions, specify the relevant subscription ID: `az account set --subscription <SUBSCRIPTION_ID>`

You can list the subscriptions via command:
```bash
az account subscription list
```

```output
[
  {
    "authorizationSource": "RoleBased",
    "displayName": "IBM xxx",
    "id": "/subscriptions/dcexxx",
    "state": "Enabled",
    "subscriptionId": "dcexxx",
    "subscriptionPolicies": {
      "locationPlacementId": "Public_2014-09-01",
      "quotaId": "EnterpriseAgreement_2014-09-01",
      "spendingLimit": "Off"
    }
  }
]
```

## Create service principal

Create the service principal that will do the installation and assign the `Contributor role`

### Set environment variables for Azure

```bash
export AZURE_SUBSCRIPTION_ID=72281667-6d54-46cb-8423-792d7bcb1234
export AZURE_LOCATION=westeurope
export AZURE_SP=pluto-01-sp
```

- `AZURE_SUBSCRIPTION_ID`: The id of your Azure subscription. Once logged in, you can retrieve this using the `az account show` command.
- `AZURE_LOCATION`: The Azure location of the resource group, for example `useast` or `westeurope`.
- `AZURE_SP`: Azure service principal that is used to create the resources on Azure.

### Create the service principal
```bash
az ad sp create-for-rbac \
  --role Contributor \
  --name ${AZURE_SP} \
  --scopes /subscriptions/${AZURE_SUBSCRIPTION_ID} | tee /tmp/${AZURE_SP}-credentials.json
```

Example output:
```output
{
  "appId": "a4c39ae9-f9d1-4038-b4a4-ab011e769111",
  "displayName": "pluto-01-sp",
  "password": "xyz-xyz",
  "tenant": "869930ac-17ee-4dda-bbad-7354c3e7629c8"
}
```

### Set permissions for service principal

Finally, set the permissions of the service principal to allow creation of the OpenShift cluster
```bash
az role assignment create \
  --role "User Access Administrator" \
  --assignee-object-id $(az ad sp list --display-name=${AZURE_SP} --query='[].id' -o tsv)
```
