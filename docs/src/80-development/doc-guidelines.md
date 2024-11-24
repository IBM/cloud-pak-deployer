## Documentation guidelines

This document contains a few formatting rules/requirements to maintain uniformity and structure across our documentation. 

## Formatting

### Code block input
Code block **inputs** should be created by surrounding the code text with three tick marks `` ``` `` key. For example, to create the following code block:
``` { .bash .copy }
oc get nodes
```

Your markdown input would look like:
````
``` { .bash .copy }
oc get nodes
```
````

### Code block output
Code block **outputs** should specify the `output` language. This can be done by putting the language after the opening tick marks. For example, to create the following code block:
```output
{
    "cloudName": "AzureCloud",
    "homeTenantId": "fcf67057-50c9-4ad4-98f3-ffca64add9e9",
    "id": "d604759d-4ce2-4dbc-b012-b9d7f1d0c185",
    "isDefault": true,
    "managedByTenants": [],
    "name": "Microsoft Azure Enterprise",
    "state": "Enabled",
    "tenantId": "fcf67057-50c9-4ad4-98f3-ffca64add9e9",
    "user": {
    "name": "example@example.com",
    "type": "user"
    }
}
```

Your markdown input would look like:
````
```output
{
    "cloudName": "AzureCloud",
    "homeTenantId": "fcf67057-50c9-4ad4-98f3-ffca64add9e9",
    "id": "d604759d-4ce2-4dbc-b012-b9d7f1d0c185",
    "isDefault": true,
    "managedByTenants": [],
    "name": "Microsoft Azure Enterprise",
    "state": "Enabled",
    "tenantId": "fcf67057-50c9-4ad4-98f3-ffca64add9e9",
    "user": {
    "name": "example@example.com",
    "type": "user"
    }
}
```
````

### Information block (inline notifications)
If you want to highlight something to reader, using an information or a warning block, use the following code:

```
!!! warning
    Warning: please do not shut down the cluster at this stage.
```

This will show up as:
!!! warning
    Warning: please do not shut down the cluster at this stage.

You can also `info` and `error`.