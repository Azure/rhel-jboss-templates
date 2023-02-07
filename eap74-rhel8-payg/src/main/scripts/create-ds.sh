#!/bin/sh

log() {
    while IFS= read -r line; do
        printf '%s %s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$line" >> /var/log/jbosseap.install.log
    done
}

# Parameters
eapRootPath=$1                                      # Root path of JBoss EAP
dbType=$2                                           # Supported database types: [postgresql]
jdbcDataSourceName=$3                               # JDBC Datasource name
jdbcDSJNDIName=$(echo "${4}" | base64 -d)           # JDBC Datasource JNDI name
dsConnectionString=$(echo "${5}" | base64 -d)       # JDBC Datasource connection String
databaseUser=$(echo "${6}" | base64 -d)             # Database username
databasePassword=$(echo "${7}" | base64 -d)         # Database user password

# Create JDBC driver module directory
jdbcDriverModuleDirectory="$eapRootPath"/modules/com/${dbType}/main
mkdir -p "$jdbcDriverModuleDirectory"

# Copy JDBC driver module template per database type
jdbcDriverModuleTemplate=${dbType}-module.xml.template
jdbcDriverModule=module.xml
cp $jdbcDriverModuleTemplate $jdbcDriverModuleDirectory/$jdbcDriverModule

# retry attempt for curl command
retryMaxAttempt=5

if [ $dbType == "postgresql" ]; then
    # Download jdbc driver
    jdbcDriverName=postgresql-42.5.2.jar
    curl --retry ${retryMaxAttempt} -Lo ${jdbcDriverModuleDirectory}/${jdbcDriverName} https://jdbc.postgresql.org/download/${jdbcDriverName}

    # Replace placeholder strings with user-input parameters
    sed -i "s/\${POSTGRESQL_JDBC_DRIVER_NAME}/${jdbcDriverName}/g" $jdbcDriverModuleDirectory/$jdbcDriverModule

    # Register JDBC driver and create data source
    sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --echo-command \
    "/subsystem=datasources/jdbc-driver=postgresql:add(driver-name=postgresql,driver-module-name=com.postgresql,driver-xa-datasource-class-name=org.postgresql.xa.PGXADataSource)" | log
    echo "data-source add --driver-name=postgresql --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --user-name=${databaseUser} --password=*** --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLExceptionSorter" | log
    sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --echo-command \
    "data-source add --driver-name=postgresql --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --user-name=${databaseUser} --password=${databasePassword} --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLExceptionSorter"
fi
