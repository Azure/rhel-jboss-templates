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
SATELLITE_VM_RESOURCE_ID=${25}
SATELLITE_ACTIVATION_KEY=${26}
SATELLITE_ORG_NAME=${27}
SATELLITE_VM_FQDN=${28}

echo "all prameters: "
echo $@

# Get storage account sas token
STORAGE_ACCESS_KEY=$(az storage account keys list --verbose --account-name "${STORAGE_ACCOUNT_NAME}" --query [0].value --output tsv)

echo "STORAGE_ACCESS_KEY: ${STORAGE_ACCESS_KEY}"

privateEndpointId=$(az storage account show --resource-group ${RESOURCE_GROUP_NAME} --name ${STORAGE_ACCOUNT_NAME} --query privateEndpointConnections[0].privateEndpoint.id -o tsv)
privateEndpointIp=$(az network private-endpoint show --ids $privateEndpointId --query customDnsConfigs[0].ipAddresses[0] -o tsv)

# Get domain controller host private IP
DOMAIN_CONTROLLER_PRIVATE_IP=$(az vm list-ip-addresses --verbose --resource-group ${RESOURCE_GROUP_NAME} --name "${VM_NAME_PREFIX}0" --query [0].virtualMachine.network.privateIpAddresses[0] --output tsv)

echo "DOMAIN_CONTROLLER_PRIVATE_IP: ${DOMAIN_CONTROLLER_PRIVATE_IP}"

# Markdown script location
SCRIPT_LOCATION=${artifactsLocation}${pathToScript}

echo "SCRIPT_LOCATION: ${SCRIPT_LOCATION}"

# Satellite server
SATELLITE_VM_PRIVATE_IP=''
if [[ "${CONNECT_SATELLITE,,}" == "true" ]]; then
    SATELLITE_VM_PRIVATE_IP=$(az vm list-ip-addresses --verbose --ids ${SATELLITE_VM_RESOURCE_ID} --query [0].virtualMachine.network.privateIpAddresses[0] --output tsv)

    echo "SATELLITE_VM_PRIVATE_IP: ${SATELLITE_VM_PRIVATE_IP}"
fi


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
        --protected-settings "{\"commandToExecute\":\"bash jbosseap-setup-standalone.sh -a $artifactsLocation -t $token -p $pathToFile -f $fileToDownload ${JBOSS_EAP_USER} ${JBOSS_EAP_PASSWORD_BASE64} ${RHSM_USER} ${RHSM_PASSWORD_BASE64} ${EAP_POOL} ${STORAGE_ACCOUNT_NAME} ${CONTAINER_NAME} ${STORAGE_ACCESS_KEY} ${CONNECT_SATELLITE} ${SATELLITE_ACTIVATION_KEY} ${SATELLITE_ORG_NAME} ${SATELLITE_VM_FQDN} ${SATELLITE_VM_PRIVATE_IP} \"}"
        echo $?
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
        --protected-settings "{\"commandToExecute\":\"bash jbosseap-setup-master.sh -a $artifactsLocation -t $token -p $pathToFile -f $fileToDownload ${JBOSS_EAP_USER} ${JBOSS_EAP_PASSWORD_BASE64} ${RHSM_USER} ${RHSM_PASSWORD_BASE64} ${EAP_POOL} ${STORAGE_ACCOUNT_NAME} ${CONTAINER_NAME} ${STORAGE_ACCESS_KEY} ${privateEndpointIp} ${CONNECT_SATELLITE} ${SATELLITE_ACTIVATION_KEY} ${SATELLITE_ORG_NAME} ${SATELLITE_VM_FQDN} ${SATELLITE_VM_PRIVATE_IP} \"}"
    # error exception
    echo $?
    echo "Domain controller VM extension execution completed"

    for ((i = 1; i < NUMBER_OF_INSTANCE; i++)); do
        echo "Configure domain slave host: ${VM_NAME_PREFIX}${i}"
        az vm extension set --verbose --name CustomScript \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --vm-name ${VM_NAME_PREFIX}${i} \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --settings "{\"fileUris\": [\"${SCRIPT_LOCATION}/jbosseap-setup-slave.sh\"]}" \
        --protected-settings "{\"commandToExecute\":\"bash jbosseap-setup-slave.sh -a $artifactsLocation -t $token -p $pathToFile -f $fileToDownload ${JBOSS_EAP_USER} ${JBOSS_EAP_PASSWORD_BASE64} ${RHSM_USER} ${RHSM_PASSWORD_BASE64} ${EAP_POOL} ${STORAGE_ACCOUNT_NAME} ${CONTAINER_NAME} ${STORAGE_ACCESS_KEY} ${privateEndpointIp} ${DOMAIN_CONTROLLER_PRIVATE_IP} ${NUMBER_OF_SERVER_INSTANCE} ${CONNECT_SATELLITE} ${SATELLITE_ACTIVATION_KEY} ${SATELLITE_ORG_NAME} ${SATELLITE_VM_FQDN} ${SATELLITE_VM_PRIVATE_IP} \"}"
        echo $?
        echo "Slave ${VM_NAME_PREFIX}${i} extension execution completed"
    done
fi
