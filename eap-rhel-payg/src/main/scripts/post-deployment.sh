set -Eeuo pipefail

# Update the IP configuration of network interface and set its private ip allocation method to Static
ipConfigName=$(az network nic show -g ${RESOURCE_GROUP_NAME} -n ${NIC_NAME} --query 'ipConfigurations[0].name' -o tsv)
az network nic ip-config update -g ${RESOURCE_GROUP_NAME} --nic-name ${NIC_NAME} -n ${ipConfigName} --set privateIpAllocationMethod=Static

# Delete uami generated before
az identity delete --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY}
