#!/bin/bash

# Get storage account sas token
STORAGE_ACCESS_KEY=$(az storage account keys list --verbose --account-name "${STORAGE_ACCOUNT_NAME}" --query [0].value --output tsv)
if [[ -z "${STORAGE_ACCESS_KEY}" ]] ; then echo  "Failed to get storage account sas token"; exit 1;  fi

# Deal with special character in Azure private offer's artifact location
eval unwrapped_artifactsLocation=${ARTIFACTS_LOCATION}

# Script URIs for creating data source connection
createDSScriptUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/create-ds.sh"
postgresqlModuleTemplateUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/postgresql-module.xml.template"

if [ "${CONFIGURATION_MODE}" != "managed-domain" ]; then
    # Configure standalone host
    for ((i = 0; i < NUMBER_OF_INSTANCE; i++)); do
        echo "Configure standalone host: ${VM_NAME_PREFIX}${i}"
        standaloneScriptUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/jbosseap-setup-standalone.sh"
        az vm extension set --verbose --name CustomScript \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --vm-name ${VM_NAME_PREFIX}${i} \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --settings "{\"fileUris\": [\"${standaloneScriptUri}\", \"${createDSScriptUri}\", \"${postgresqlModuleTemplateUri}\"]}" \
        --protected-settings "{\"commandToExecute\":\"sh jbosseap-setup-standalone.sh -a ${ARTIFACTS_LOCATION} -t ${ARTIFACTS_LOCATION_SAS_TOKEN} -p ${PATH_TO_FILE} -f ${FILE_TO_DOWNLOAD} ${JBOSS_EAP_USER} ${JBOSS_EAP_PASSWORD_BASE64} ${RHSM_USER} ${RHSM_PASSWORD_BASE64} ${EAP_POOL} ${RHEL_POOL} ${JDK_VERSION} ${STORAGE_ACCOUNT_NAME} ${CONTAINER_NAME} ${STORAGE_ACCESS_KEY} ${CONNECT_SATELLITE} ${SATELLITE_ACTIVATION_KEY_BASE64} ${SATELLITE_ORG_NAME_BASE64} ${SATELLITE_VM_FQDN} ${ENABLE_DB} ${DATABASE_TYPE} ${JDBC_DATA_SOURCE_JNDI_NAME_BASE64} ${DS_CONNECTION_URL_BASE64} ${DB_USER_BASE64} ${DB_PASSWORD_BASE64}\"}"
        if [ $? != 0 ] ; then echo  "Failed to configure standalone host ${VM_NAME_PREFIX}${i}"; exit 1;  fi
        echo "standalone ${VM_NAME_PREFIX}${i} extension execution completed"
    done
else
    privateEndpointId=$(az storage account show --resource-group ${RESOURCE_GROUP_NAME} --name ${STORAGE_ACCOUNT_NAME} --query privateEndpointConnections[0].privateEndpoint.id -o tsv)
    if [[ -z "${privateEndpointId}" ]] ; then echo  "Failed to get private endpoint ID"; exit 1;  fi

    privateEndpointIp=$(az network private-endpoint show --ids $privateEndpointId --query customDnsConfigs[0].ipAddresses[0] -o tsv)
    if [[ -z "${privateEndpointIp}" ]] ; then echo  "Failed to get private endpoint IP"; exit 1;  fi

    # Get domain controller host private IP
    DOMAIN_CONTROLLER_PRIVATE_IP=$(az vm list-ip-addresses --verbose --resource-group ${RESOURCE_GROUP_NAME} --name "${ADMIN_VM_NAME}" --query [0].virtualMachine.network.privateIpAddresses[0] --output tsv)
    if [[ -z "${DOMAIN_CONTROLLER_PRIVATE_IP}" ]] ; then echo  "Failed to get domain controller host private IP"; exit 1;  fi

    enableElytronSe17DomainCliUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/enable-elytron-se17-domain.cli"

    # Configure domain controller host
    echo "Configure domain controller host: ${ADMIN_VM_NAME}"
    masterScriptUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/jbosseap-setup-master.sh"
    az vm extension set --verbose --name CustomScript \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --vm-name ${ADMIN_VM_NAME} \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --settings "{\"fileUris\": [\"${masterScriptUri}\", \"${enableElytronSe17DomainCliUri}\", \"${createDSScriptUri}\", \"${postgresqlModuleTemplateUri}\"]}" \
        --protected-settings "{\"commandToExecute\":\"sh jbosseap-setup-master.sh ${JBOSS_EAP_USER} ${JBOSS_EAP_PASSWORD_BASE64} ${RHSM_USER} ${RHSM_PASSWORD_BASE64} ${EAP_POOL} ${RHEL_POOL} ${JDK_VERSION} ${STORAGE_ACCOUNT_NAME} ${CONTAINER_NAME} ${STORAGE_ACCESS_KEY} ${privateEndpointIp} ${CONNECT_SATELLITE} ${SATELLITE_ACTIVATION_KEY_BASE64} ${SATELLITE_ORG_NAME_BASE64} ${SATELLITE_VM_FQDN} ${ENABLE_DB} ${DATABASE_TYPE} ${JDBC_DATA_SOURCE_JNDI_NAME_BASE64} ${DS_CONNECTION_URL_BASE64} ${DB_USER_BASE64} ${DB_PASSWORD_BASE64}\"}"
        if [ $? != 0 ] ; then echo  "Failed to configure domain controller host: ${ADMIN_VM_NAME}"; exit 1;  fi
        echo "Domain controller VM extension execution completed"

    for ((i = 1; i < NUMBER_OF_INSTANCE; i++)); do
        echo "Configure domain slave host: ${VM_NAME_PREFIX}${i}"
        slaveScriptUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/jbosseap-setup-slave.sh"
        az vm extension set --verbose --name CustomScript \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --vm-name ${VM_NAME_PREFIX}${i} \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --settings "{\"fileUris\": [\"${slaveScriptUri}\", \"${enableElytronSe17DomainCliUri}\", \"${createDSScriptUri}\", \"${postgresqlModuleTemplateUri}\"]}" \
        --protected-settings "{\"commandToExecute\":\"sh jbosseap-setup-slave.sh ${JBOSS_EAP_USER} ${JBOSS_EAP_PASSWORD_BASE64} ${RHSM_USER} ${RHSM_PASSWORD_BASE64} ${EAP_POOL} ${RHEL_POOL} ${JDK_VERSION} ${STORAGE_ACCOUNT_NAME} ${CONTAINER_NAME} ${STORAGE_ACCESS_KEY} ${privateEndpointIp} ${DOMAIN_CONTROLLER_PRIVATE_IP} ${NUMBER_OF_SERVER_INSTANCE} ${CONNECT_SATELLITE} ${SATELLITE_ACTIVATION_KEY_BASE64} ${SATELLITE_ORG_NAME_BASE64} ${SATELLITE_VM_FQDN} ${ENABLE_DB} ${DATABASE_TYPE} ${JDBC_DATA_SOURCE_JNDI_NAME_BASE64} ${DS_CONNECTION_URL_BASE64} ${DB_USER_BASE64} ${DB_PASSWORD_BASE64}\"}"
        if [ $? != 0 ] ; then echo  "Failed to configure domain slave host: ${VM_NAME_PREFIX}${i}"; exit 1;  fi
        echo "Slave ${VM_NAME_PREFIX}${i} extension execution completed"
    done
fi

# Delete uami generated before
az identity delete --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY}
