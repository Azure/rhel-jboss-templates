#!/bin/bash

while getopts "a:t:p:f:s:" opt; do
    case $opt in
        a)
            artifactsLocation=$OPTARG #base uri of the file including the container
        ;;
        t)
            token=$OPTARG #saToken for the uri - use "?" if the artifact is not secured via sasToken
        ;;
        p)
            pathToFile=$OPTARG #path to the file relative to artifactsLocation
        ;;
        f)
            fileToDownload=$OPTARG #filename of the file to download from storage
        ;;
        s)
            pathToScript=$OPTARG #filename of the file to download from storage
        ;;
    esac
done

JBOSS_EAP_USER=${11}
JBOSS_EAP_PASSWORD_BASE64=${12}
RHSM_USER=${13}
RHSM_PASSWORD_BASE64=${14}
EAP_POOL=${15}
STORAGE_ACCOUNT_NAME=${16}
CONTAINER_NAME=${17}
RESOURCE_GROUP_NAME=${18}
NUMBER_OF_INSTANCE=${19}
VM_NAME_PREFIX=${20}
NUMBER_OF_SERVER_INSTANCE=${21}
CONFIGURATION_MODE=${22}
VNET_NEW_OR_EXISTING=${23}
CONNECT_SATELLITE=${24}
SATELLITE_ACTIVATION_KEY_BASE64=${25}
SATELLITE_ORG_NAME_BASE64=${26}
SATELLITE_VM_FQDN=${27}

# Get storage account sas token
STORAGE_ACCESS_KEY=$(az storage account keys list --verbose --account-name "${STORAGE_ACCOUNT_NAME}" --query [0].value --output tsv)
if [[ -z "${STORAGE_ACCESS_KEY}" ]] ; then echo "Failed to get storage account sas token"; exit 1; fi

privateEndpointId=$(az storage account show --resource-group ${RESOURCE_GROUP_NAME} --name ${STORAGE_ACCOUNT_NAME} --query privateEndpointConnections[0].privateEndpoint.id -o tsv)
if [[ -z "${privateEndpointId}" ]] ; then echo "Failed to get private endpoint ID"; exit 1; fi

privateEndpointIp=$(az network private-endpoint show --ids $privateEndpointId --query customDnsConfigs[0].ipAddresses[0] -o tsv)
if [[ -z "${privateEndpointIp}" ]] ; then echo "Failed to get private endpoint IP"; exit 1; fi

# Get domain controller host private IP
DOMAIN_CONTROLLER_PRIVATE_IP=$(az vm list-ip-addresses --verbose --resource-group ${RESOURCE_GROUP_NAME} --name "${VM_NAME_PREFIX}0" --query [0].virtualMachine.network.privateIpAddresses[0] --output tsv)
if [[ -z "${DOMAIN_CONTROLLER_PRIVATE_IP}" ]] ; then echo "Failed to get domain controller host private IP"; exit 1; fi

# Markdown script location
SCRIPT_LOCATION=${artifactsLocation}${pathToScript}

if [ "${CONFIGURATION_MODE}" != "managed-domain" ]; then
    # Configure standalone host
    for ((i = 0; i < NUMBER_OF_INSTANCE; i++)); do
        echo "Configure standalone host: ${VM_NAME_PREFIX}${i}"
        az vm extension set --verbose --name CustomScript \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --vm-name ${VM_NAME_PREFIX}${i} \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --settings "{\"fileUris\": [\"${SCRIPT_LOCATION}/jbosseap-setup-standalone.sh\"]}" \
        --protected-settings "{\"commandToExecute\":\"bash jbosseap-setup-standalone.sh -a $artifactsLocation -t $token -p $pathToFile -f $fileToDownload ${JBOSS_EAP_USER} ${JBOSS_EAP_PASSWORD_BASE64} ${RHSM_USER} ${RHSM_PASSWORD_BASE64} ${EAP_POOL} ${STORAGE_ACCOUNT_NAME} ${CONTAINER_NAME} ${STORAGE_ACCESS_KEY} ${CONNECT_SATELLITE} ${SATELLITE_ACTIVATION_KEY_BASE64} ${SATELLITE_ORG_NAME_BASE64} ${SATELLITE_VM_FQDN} \"}"
        if [ $? != 0 ] ; then echo "Failed to configure standalone host ${VM_NAME_PREFIX}${i}"; exit 1; fi
        echo "standalone ${VM_NAME_PREFIX}${i} extension execution completed"
    done
else
    # Configure domain controller host
    echo "Configure domain controller host: ${VM_NAME_PREFIX}0"

    az vm extension set --verbose --name CustomScript \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --vm-name ${VM_NAME_PREFIX}0 \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --settings "{\"fileUris\": [\"${SCRIPT_LOCATION}/jbosseap-setup-master.sh\"]}" \
        --protected-settings "{\"commandToExecute\":\"bash jbosseap-setup-master.sh -a $artifactsLocation -t $token -p $pathToFile -f $fileToDownload ${JBOSS_EAP_USER} ${JBOSS_EAP_PASSWORD_BASE64} ${RHSM_USER} ${RHSM_PASSWORD_BASE64} ${EAP_POOL} ${STORAGE_ACCOUNT_NAME} ${CONTAINER_NAME} ${STORAGE_ACCESS_KEY} ${privateEndpointIp} ${CONNECT_SATELLITE} ${SATELLITE_ACTIVATION_KEY_BASE64} ${SATELLITE_ORG_NAME_BASE64} ${SATELLITE_VM_FQDN} \"}"
        # error exception
        if [ $? != 0 ] ; then echo "Failed to configure domain controller host: ${VM_NAME_PREFIX}0"; exit 1; fi
        echo "Domain controller VM extension execution completed"

    for ((i = 1; i < NUMBER_OF_INSTANCE; i++)); do
        echo "Configure domain slave host: ${VM_NAME_PREFIX}${i}"
        az vm extension set --verbose --name CustomScript \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --vm-name ${VM_NAME_PREFIX}${i} \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --settings "{\"fileUris\": [\"${SCRIPT_LOCATION}/jbosseap-setup-slave.sh\"]}" \
        --protected-settings "{\"commandToExecute\":\"bash jbosseap-setup-slave.sh -a $artifactsLocation -t $token -p $pathToFile -f $fileToDownload ${JBOSS_EAP_USER} ${JBOSS_EAP_PASSWORD_BASE64} ${RHSM_USER} ${RHSM_PASSWORD_BASE64} ${EAP_POOL} ${STORAGE_ACCOUNT_NAME} ${CONTAINER_NAME} ${STORAGE_ACCESS_KEY} ${privateEndpointIp} ${DOMAIN_CONTROLLER_PRIVATE_IP} ${NUMBER_OF_SERVER_INSTANCE} ${CONNECT_SATELLITE} ${SATELLITE_ACTIVATION_KEY_BASE64} ${SATELLITE_ORG_NAME_BASE64} ${SATELLITE_VM_FQDN} \"}"
        if [ $? != 0 ] ; then echo "Failed to configure domain slave host: ${VM_NAME_PREFIX}${i}"; exit 1; fi
        echo "Slave ${VM_NAME_PREFIX}${i} extension execution completed"
    done
fi
