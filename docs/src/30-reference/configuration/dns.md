# Upstream DNS servers for OpenShift

When deploying OpenShift in a private network, one may want to reach additional private network services by their host name. Examples could be a database server, Hadoop cluster or an LDAP server.  OpenShift provides a DNS operator which deploys and manages CoreDNS which takes care of name resolution for pods running inside the container platform, also known as DNS forwarding.

If the services that need to be reachable our registered on public DNS servers, you typically do not have to configure upstream DNS servers.

The upstream DNS used for a particular OpenShift cluster is configured like this:
```
openshift:
- name: sample
...
  upstream_dns:
  - name: sample-dns
    zones:
    - example.com
    dns_servers:
    - 172.31.2.73:53
```

The zones which have been defined for each of the upstream_dns configurations control which DNS server(s) will be used for name resolution. For example, if `example.com` is given as the zone and an upstream DNS server of `172.31.2.73:53`, any host name matching `*.example.com` will be resolved using DNS server `172.31.2.73` and port `53`.

If you want to remove the upstream DNS that was previously configured, you can change the deployer configuration as below and run the deployer. Removing the `upstream_dns` element altogether will not make changes to the OpenShift DNS operator.

```
  upstream_dns: []
```

See https://docs.openshift.com/container-platform/4.8/networking/dns-operator.html for more information about the operator that is configured by specifying upstream DNS servers.

#### Property explanation
| Property       | Description                                                                            | Mandatory | Allowed values |
| -------------- | -------------------------------------------------------------------------------------- | --------- | -------------- |
| upstream_dns[] | List of alternative upstream DNS servers(s) for OpenShift                              | No        |                |
| name           | Name of the upstream DNS entry                                                         | Yes       |                |
| zones          | Specification of one or more zone for which the DNS server is applicable               | Yes       |                |
| dns_servers    | One or more DNS servers (host:port) that will resolve host names in the specified zone | Yes       |                |
