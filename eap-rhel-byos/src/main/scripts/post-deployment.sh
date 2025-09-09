#!/bin/bash

#      Copyright (c) Microsoft Corporation.
#      Copyright (c) IBM Corporation. 
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#           http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

set -Eeuo pipefail

# Go through all public IPs assigned to the network interfaces in resource group ${RESOURCE_GROUP_NAME}, and do the following:
# * If there is tag named ${GUID_TAG} (regardless of value), update the network interface to remove the public IP
# Finally, delete all these public IPs at once
PUBLIC_IPS=$(az network public-ip list --resource-group "${RESOURCE_GROUP_NAME}" --query "[?tags && contains(keys(tags), '${GUID_TAG}')].id" -o tsv)
if [ -n "${PUBLIC_IPS}" ]; then
    echo "Found public IPs to remove: ${PUBLIC_IPS}"
    for PUBLIC_IP in ${PUBLIC_IPS}; do
        IP_CONFIG_ID=$(az network public-ip show --ids "${PUBLIC_IP}" --query "ipConfiguration.id" -o tsv)
        if [ -n "${IP_CONFIG_ID}" ]; then
            echo "Found IP configuration: ${IP_CONFIG_ID}"
            # Extract NIC name and IP config name from the IP configuration ID
            # Format: /subscriptions/.../resourceGroups/.../providers/Microsoft.Network/networkInterfaces/NIC_NAME/ipConfigurations/IP_CONFIG_NAME
            NIC_NAME=$(echo "${IP_CONFIG_ID}" | sed 's|.*/networkInterfaces/\([^/]*\)/.*|\1|')
            IP_CONFIG_NAME=$(echo "${IP_CONFIG_ID}" | sed 's|.*/ipConfigurations/\([^/]*\).*|\1|')
            
            echo "Removing public IP from NIC: ${NIC_NAME}, IP config: ${IP_CONFIG_NAME}"
            az network nic ip-config update -g "${RESOURCE_GROUP_NAME}" --nic-name "${NIC_NAME}" -n "${IP_CONFIG_NAME}" --remove publicIPAddress
        fi
    done

    echo "Deleting public IPs: ${PUBLIC_IPS}"
    az network public-ip delete --ids ${PUBLIC_IPS}
else
    echo "No public IPs found with tag ${GUID_TAG}"
fi

# Delete uami generated before
az identity delete --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY}