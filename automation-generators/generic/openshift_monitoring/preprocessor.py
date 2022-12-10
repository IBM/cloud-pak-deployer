from generatorPreProcessor import GeneratorPreProcessor
import sys

# Validating:
# ---
# openshift_monitoring:
# - openshift_cluster_name: {{ env_id }}
#   user_workload: enabled
#   pvc_storage_class: ibmc-vpc-block-retain-general-purpose
#   pvc_storage_size_gb: 100
#   remote_rewrite_url: http://daprintdbrwsbx.dap:9201/write
#   retention_period: 1y
#   grafana_operator: enabled
#   grafana_project: grafana
#   labels:
#     cluster_name: "{{ env_id }}"

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('openshift_cluster_name').isRequired()
    g('user_workload').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:

        ge=g.getExpandedAttributes()
        
        if "pvc_storage_class" in ge:
            if "pvc_storage_size_gb" not in ge:
                g.appendError(msg='Attribute pvc_storage_size_gb must be specified when pvc_storage_class is specified')

        if "pvc_storage_size_gb" in ge:
            if not isinstance(ge['pvc_storage_size_gb'],int):
                g.appendError(msg='pvc_storage_size_gb value must be numeric')

            if "pvc_storage_class" not in ge:
                g.appendError(msg='Attribute pvc_storage_class must be specified when pvc_storage_size_gb is specified')

        if "grafana_operator" in ge:
            if "grafana_project" not in ge:
                g.appendError(msg='Attribute grafana_project must be specified when grafana_operator is specified')

        if "grafana_project" in ge:
            if "grafana_operator" not in ge:
                g.appendError(msg='Attribute grafana_operator must be specified when grafana_project is specified')



    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result