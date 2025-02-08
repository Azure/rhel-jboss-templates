#!/bin/bash

# Get storage account sas token
STORAGE_ACCESS_KEY=$(az storage account keys list --verbose --account-name "${STORAGE_ACCOUNT_NAME}" --query [0].value --output tsv)
if [[ -z "${STORAGE_ACCESS_KEY}" ]] ; then echo  "Failed to get storage account sas token"; exit 1;  fi

# Deal with special character in Azure private offer's artifact location
eval unwrapped_artifactsLocation=${ARTIFACTS_LOCATION}

# Script URIs for creating data source connection
postgresqlDSScriptUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/create-ds-postgresql.sh"
mssqlserverDSScriptUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/create-ds-mssqlserver.sh"
oracleDSScriptUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/create-ds-oracle.sh"
mysqlDSScriptUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/create-ds-mysql.sh"

if [ "${CONFIGURATION_MODE}" != "managed-domain" ]; then
    # Configure standalone host
    for ((i = 0; i < NUMBER_OF_INSTANCE; i++)); do
        # Update the IP configuration of network interface and set its private ip allocation method to Static
        ipConfigName=$(az network nic show -g ${RESOURCE_GROUP_NAME} -n ${NIC_NAME}${i} --query 'ipConfigurations[0].name' -o tsv)
        echo "Set private ip allocation method to Static for host: ${VM_NAME_PREFIX}${i}"
        az network nic ip-config update -g ${RESOURCE_GROUP_NAME} --nic-name ${NIC_NAME}${i} -n ${ipConfigName} --set privateIpAllocationMethod=Static

        echo "Configure standalone host: ${VM_NAME_PREFIX}${i}"
        standaloneScriptUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/jbosseap-setup-standalone.sh"
        az vm extension set --verbose --name CustomScript \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --vm-name ${VM_NAME_PREFIX}${i} \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --settings "{\"fileUris\": [\"${standaloneScriptUri}\", \"${postgresqlDSScriptUri}\", \"${mssqlserverDSScriptUri}\", \"${oracleDSScriptUri}\", \"${mysqlDSScriptUri}\"]}" \
        --protected-settings "{\"commandToExecute\":\"sh jbosseap-setup-standalone.sh -a ${ARTIFACTS_LOCATION} -t ${ARTIFACTS_LOCATION_SAS_TOKEN} -p ${PATH_TO_FILE} -f ${FILE_TO_DOWNLOAD} ${JBOSS_EAP_USER} ${JBOSS_EAP_PASSWORD_BASE64} ${RHSM_USER} ${RHSM_PASSWORD_BASE64} ${EAP_POOL} ${RHEL_POOL} ${JDK_VERSION} ${STORAGE_ACCOUNT_NAME} ${CONTAINER_NAME} ${STORAGE_ACCESS_KEY} ${CONNECT_SATELLITE} ${SATELLITE_ACTIVATION_KEY_BASE64} ${SATELLITE_ORG_NAME_BASE64} ${SATELLITE_VM_FQDN} ${ENABLE_DB} ${DATABASE_TYPE} ${JDBC_DATA_SOURCE_JNDI_NAME_BASE64} ${DS_CONNECTION_URL_BASE64} ${DB_USER_BASE64} ${DB_PASSWORD_BASE64} ${gracefulShutdownTimeout}\"}"
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

    # Update the IP configuration of network interface and set its private ip allocation method to Static
    ipConfigName=$(az network nic show -g ${RESOURCE_GROUP_NAME} -n ${NIC_NAME}0 --query 'ipConfigurations[0].name' -o tsv)
    echo "Set private ip allocation method to Static for host: ${ADMIN_VM_NAME}"
    az network nic ip-config update -g ${RESOURCE_GROUP_NAME} --nic-name ${NIC_NAME}0 -n ${ipConfigName} --set privateIpAllocationMethod=Static

    # Configure domain controller host
    echo "Configure domain controller host: ${ADMIN_VM_NAME}"
    masterScriptUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/jbosseap-setup-master.sh"
    az vm extension set --verbose --name CustomScript \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --vm-name ${ADMIN_VM_NAME} \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --settings "{\"fileUris\": [\"${masterScriptUri}\", \"${enableElytronSe17DomainCliUri}\"]}" \
        --protected-settings "{\"commandToExecute\":\"sh jbosseap-setup-master.sh ${JBOSS_EAP_USER} ${JBOSS_EAP_PASSWORD_BASE64} ${RHSM_USER} ${RHSM_PASSWORD_BASE64} ${EAP_POOL} ${RHEL_POOL} ${JDK_VERSION} ${STORAGE_ACCOUNT_NAME} ${CONTAINER_NAME} ${STORAGE_ACCESS_KEY} ${privateEndpointIp} ${CONNECT_SATELLITE} ${SATELLITE_ACTIVATION_KEY_BASE64} ${SATELLITE_ORG_NAME_BASE64} ${SATELLITE_VM_FQDN} ${gracefulShutdownTimeout}\"}"
        if [ $? != 0 ] ; then echo  "Failed to configure domain controller host: ${ADMIN_VM_NAME}"; exit 1;  fi
        echo "Domain controller VM extension execution completed"

    for ((i = 1; i < NUMBER_OF_INSTANCE; i++)); do
        # Update the IP configuration of network interface and set its private ip allocation method to Static
        ipConfigName=$(az network nic show -g ${RESOURCE_GROUP_NAME} -n ${NIC_NAME}${i} --query 'ipConfigurations[0].name' -o tsv)
        echo "Set private ip allocation method to Static for host: ${VM_NAME_PREFIX}${i}"
        az network nic ip-config update -g ${RESOURCE_GROUP_NAME} --nic-name ${NIC_NAME}${i} -n ${ipConfigName} --set privateIpAllocationMethod=Static

        echo "Configure domain slave host: ${VM_NAME_PREFIX}${i}"
        slaveScriptUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/jbosseap-setup-slave.sh"
        az vm extension set --verbose --name CustomScript \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --vm-name ${VM_NAME_PREFIX}${i} \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --settings "{\"fileUris\": [\"${slaveScriptUri}\", \"${enableElytronSe17DomainCliUri}\", \"${postgresqlDSScriptUri}\", \"${mssqlserverDSScriptUri}\", \"${oracleDSScriptUri}\", \"${mysqlDSScriptUri}\"]}" \
        --protected-settings "{\"commandToExecute\":\"sh jbosseap-setup-slave.sh ${JBOSS_EAP_USER} ${JBOSS_EAP_PASSWORD_BASE64} ${RHSM_USER} ${RHSM_PASSWORD_BASE64} ${EAP_POOL} ${RHEL_POOL} ${JDK_VERSION} ${STORAGE_ACCOUNT_NAME} ${CONTAINER_NAME} ${STORAGE_ACCESS_KEY} ${privateEndpointIp} ${DOMAIN_CONTROLLER_PRIVATE_IP} ${NUMBER_OF_SERVER_INSTANCE} ${CONNECT_SATELLITE} ${SATELLITE_ACTIVATION_KEY_BASE64} ${SATELLITE_ORG_NAME_BASE64} ${SATELLITE_VM_FQDN} ${ENABLE_DB} ${DATABASE_TYPE} ${JDBC_DATA_SOURCE_JNDI_NAME_BASE64} ${DS_CONNECTION_URL_BASE64} ${DB_USER_BASE64} ${DB_PASSWORD_BASE64} ${gracefulShutdownTimeout}\"}"
        if [ $? != 0 ] ; then echo  "Failed to configure domain slave host: ${VM_NAME_PREFIX}${i}"; exit 1;  fi
        echo "Slave ${VM_NAME_PREFIX}${i} extension execution completed"
    done

    # deploy sample app to domain controller
    echo "Deploy sample app to domain controller: ${ADMIN_VM_NAME}"
    az vm extension set --verbose --name CustomScript \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --vm-name ${ADMIN_VM_NAME} \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --settings "{\"fileUris\": [\"${unwrapped_artifactsLocation}/deploy-sample-app.sh\"]}" \
        --protected-settings "{\"commandToExecute\":\"sh deploy-sample-app.sh  -a ${ARTIFACTS_LOCATION} -t ${ARTIFACTS_LOCATION_SAS_TOKEN} -p ${PATH_TO_FILE} -f ${FILE_TO_DOWNLOAD}\"}"

    if [ "$ENABLE_DB" == "True" ]; then
        # Configure data source
        echo "Configure data source for host: ${ADMIN_VM_NAME}"
        masterDSScriptUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/jbosseap-setup-master-ds.sh"
        jdbcDataSourceName=dataSource-$DATABASE_TYPE
        az vm extension set --verbose --name CustomScript \
            --resource-group ${RESOURCE_GROUP_NAME} \
            --vm-name ${ADMIN_VM_NAME} \
            --publisher Microsoft.Azure.Extensions \
            --version 2.0 \
            --settings "{\"fileUris\": [\"${masterDSScriptUri}\", \"${postgresqlDSScriptUri}\", \"${mssqlserverDSScriptUri}\", \"${oracleDSScriptUri}\", \"${mysqlDSScriptUri}\"]}" \
            --protected-settings "{\"commandToExecute\":\"sh jbosseap-setup-master-ds.sh ${DATABASE_TYPE} ${jdbcDataSourceName} ${JDBC_DATA_SOURCE_JNDI_NAME_BASE64} ${DS_CONNECTION_URL_BASE64} ${DB_USER_BASE64} ${DB_PASSWORD_BASE64}\"}"
            if [ $? != 0 ] ; then echo  "Failed to configure data source for host: ${ADMIN_VM_NAME}"; exit 1;  fi
            echo "Data source configuration VM extension execution completed"

        # Test data source connection in worker nodes
        for ((i = 1; i < NUMBER_OF_INSTANCE; i++)); do
            echo "Test data source connection in workder node: ${VM_NAME_PREFIX}${i}"
            slaveTestDSConnScriptUri="${unwrapped_artifactsLocation}${PATH_TO_SCRIPT}/jbosseap-test-slave-ds.sh"
            az vm extension set --verbose --name CustomScript \
            --resource-group ${RESOURCE_GROUP_NAME} \
            --vm-name ${VM_NAME_PREFIX}${i} \
            --publisher Microsoft.Azure.Extensions \
            --version 2.0 \
            --settings "{\"fileUris\": [\"${slaveTestDSConnScriptUri}\"]}" \
            --protected-settings "{\"commandToExecute\":\"sh jbosseap-test-slave-ds.sh ${JBOSS_EAP_USER} ${JBOSS_EAP_PASSWORD_BASE64} ${DOMAIN_CONTROLLER_PRIVATE_IP} ${NUMBER_OF_SERVER_INSTANCE} ${jdbcDataSourceName}\"}"
            if [ $? != 0 ] ; then echo  "Test data source connection failed for worker node: ${VM_NAME_PREFIX}${i}"; exit 1;  fi
            echo "Worker node ${VM_NAME_PREFIX}${i} data source connection test extension execution completed"
        done
    fi  
fi

# Delete uami generated before
az identity delete --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY}
