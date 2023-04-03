#!/bin/sh

log() {
    while IFS= read -r line; do
        printf '%s %s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$line" >> /var/log/jbosseap.install.log
    done
}

JBOSS_EAP_USER=${1}
JBOSS_EAP_PASSWORD_BASE64=${2}
JBOSS_EAP_PASSWORD=$(echo $JBOSS_EAP_PASSWORD_BASE64 | base64 -d)
DOMAIN_CONTROLLER_PRIVATE_IP=${3}
NUMBER_OF_SERVER_INSTANCE=${4}
jdbcDataSourceName=${5}

HOST_VM_NAME=$(hostname)
HOST_VM_NAME_LOWERCASES=$(echo "${HOST_VM_NAME,,}")
FQDN=$(hostname -A)
FQDN_LOWERCASES=$(echo "${FQDN,,}")

# Load environment variables where EAP_HOME is defined
source /etc/profile.d/eap_env.sh

# Test connection for the created data source
echo "Start to test data source connection" | log
for ((i = 0; i < NUMBER_OF_SERVER_INSTANCE; i++)); do
    sudo -u jboss $EAP_HOME/wildfly/bin/jboss-cli.sh --connect --controller=${DOMAIN_CONTROLLER_PRIVATE_IP} --user=${JBOSS_EAP_USER} --password=${JBOSS_EAP_PASSWORD} \
        "/host=${HOST_VM_NAME_LOWERCASES}/server=${HOST_VM_NAME_LOWERCASES}-server${i}/subsystem=datasources/data-source=$jdbcDataSourceName:test-connection-in-pool" | log; flag=${PIPESTATUS[0]}
    if [ $flag != 0 ]; then
        # Retry data source connection test using FQDN of the worker node
        sudo -u jboss $EAP_HOME/wildfly/bin/jboss-cli.sh --connect --controller=${DOMAIN_CONTROLLER_PRIVATE_IP} --user=${JBOSS_EAP_USER} --password=${JBOSS_EAP_PASSWORD} \
            "/host=${FQDN_LOWERCASES}/server=${HOST_VM_NAME_LOWERCASES}-server${i}/subsystem=datasources/data-source=$jdbcDataSourceName:test-connection-in-pool" | log; flag=${PIPESTATUS[0]}
        if [ $flag != 0 ]; then 
            echo "ERROR! Test data source connection failed." >&2 log
            exit $flag
        fi
    fi
done
echo "Complete to test data source connection" | log
