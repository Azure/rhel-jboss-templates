#!/bin/sh
set -Eeuo pipefail

log() {
    while IFS= read -r line; do
        printf '%s %s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$line" >> /var/log/jbosseap.install.log
    done
}

dbType=${1}
jdbcDataSourceName=${2}
jdbcDSJNDIName=${3}
dsConnectionString=${4}
databaseUser=${5}
databasePassword=${6}

# Load environment variables where EAP_HOME is defined
source /etc/profile.d/eap_env.sh

# Configure JDBC driver and data source
echo "Start to configure JDBC driver and data source" | log
./create-ds-${dbType}.sh $EAP_HOME "$jdbcDataSourceName" "$jdbcDSJNDIName" "$dsConnectionString" "$databaseUser" "$databasePassword" true false
echo "Complete to configure JDBC driver and data source" | log
