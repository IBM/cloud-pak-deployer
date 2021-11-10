# Since terraform doesn't support whole module dependencies, if your module requires portworx to have been instantiated before creating other resources, create a variable in your module that is passed this output value. Make the portworx-dependent resources in your module dependent on that variable. The value is not relevant.

# output "zone_name" {
#   depends_on = [
#     data.external.get_zone_from_subnet
#   ]
#   value = var.enable && length(data.external.get_zone_from_subnet) > 0 ? data.external.get_zone_from_subnet.0.result.zone_name : null
# }

output "portworx_is_ready" {
  depends_on = [
    ibm_resource_instance.portworx,
    null_resource.delete_db2_sc,
    null_resource.px_sc
  ]
  value = length(ibm_resource_instance.portworx) > 0 ? ibm_resource_instance.portworx[0].id : null
}
