#!/bin/sh
set -Eeuo pipefail

log() {
    while IFS= read -r line; do
        printf '%s %s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$line" >> /var/log/jbosseap.install.log
    done
}

# Parameters
eapRootPath=$1                                      # Root path of JBoss EAP
jdbcDataSourceName=$2                               # JDBC Datasource name
jdbcDSJNDIName=$(echo "${3}" | base64 -d)           # JDBC Datasource JNDI name
dsConnectionString=$(echo "${4}" | base64 -d)       # JDBC Datasource connection String
databaseUser=$(echo "${5}" | base64 -d)             # Database username
databasePassword=$(echo "${6}" | base64 -d)         # Database user password
isManagedDomain=$7                                  # true if the server is in a managed domain, false otherwise
isSlaveServer=$8                                    # true if it's a slave server of a managed domain, false otherwise
enablePswlessConnection=$9                          # Enable passwordless connection
uamiClientId=$10                                    # UAMI display name

azureIdentityExtensionVersion=1.1.20
jdbcDriverVersion=42.5.2
if [ "$(echo "$enablePswlessConnection" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
echo "enablePswlessConnection=true, creating passwordless connection" | log
    # Create JDBC driver and module directory
    jdbcDriverModuleDirectory="$eapRootPath"/modules/com/postgresql/main
    mkdir -p "$jdbcDriverModuleDirectory"

    # Download JDBC driver and passwordless extensions
    extensionJarName=azure-identity-extensions-${azureIdentityExtensionVersion}.jar
    extensionPomName=azure-identity-extensions-${azureIdentityExtensionVersion}.pom
    sudo curl --retry 5 -Lo ${jdbcDriverModuleDirectory}/${extensionJarName} https://repo1.maven.org/maven2/com/azure/azure-identity-extensions/${azureIdentityExtensionVersion}/$extensionJarName
    sudo curl --retry 5 -Lo ${jdbcDriverModuleDirectory}/${extensionPomName} https://repo1.maven.org/maven2/com/azure/azure-identity-extensions/${azureIdentityExtensionVersion}/$extensionPomName

    sudo yum install maven -y
    sudo mvn dependency:copy-dependencies  -f ${jdbcDriverModuleDirectory}/${extensionPomName} -Ddest=${jdbcDriverModuleDirectory}

    # Create module for JDBC driver
    jdbcDriverModule=module.xml
    sudo cat <<EOF >${jdbcDriverModule}
<?xml version="1.0" ?>
<module xmlns="urn:jboss:module:1.1" name="com.postgresql">
  <resources>
    <resource-root path="${extensionJarName}"/>
EOF

    # Add all jars from target/dependency
    for jar in ${jdbcDriverModuleDirectory}/target/dependency/*.jar; do
    if [ -f "$jar" ]; then
    # Extract just the filename from the path
    jarname=$(basename "$jar")
    echo "    <resource-root path=\"target/dependency/${jarname}\"/>" >> ${jdbcDriverModule}
    fi
    done

    # Add the closing tags
    cat <<EOF >> ${jdbcDriverModule}
  </resources>
  <dependencies>
    <module name="javaee.api"/>
    <module name="sun.jdk"/>
    <module name="ibm.jdk"/>
    <module name="javax.api"/>
    <module name="javax.transaction.api"/>
  </dependencies>
</module>
EOF

    chmod 644 $jdbcDriverModule
    mv $jdbcDriverModule $jdbcDriverModuleDirectory/$jdbcDriverModule
    export dsConnectionString="$dsConnectionString?sslmode=require&azure.clientId=$uamiClientId&authenticationPluginClassName=com.azure.identity.extensions.jdbc.postgresql.AzurePostgresqlAuthenticationPlugin"

    if [ $isManagedDomain == "false" ]; then
            # Register JDBC driver
            sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --echo-command \
            "/subsystem=datasources/jdbc-driver=postgresql:add(driver-name=postgresql,driver-module-name=com.postgresql,driver-xa-datasource-class-name=org.postgresql.xa.PGXADataSource)" | log

            # Create data source
            echo "data-source add --driver-name=postgresql --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --user-name=${databaseUser} --password=*** --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLExceptionSorter" | log
            sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --echo-command \
            "data-source add --driver-name=postgresql --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --user-name=${databaseUser} --password=${databasePassword} --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLExceptionSorter"
        elif [ $isSlaveServer == "false" ]; then
            # Register JDBC driver with ha profile
            sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --controller=$(hostname -I) --echo-command \
            "/profile=ha/subsystem=datasources/jdbc-driver=postgresql:add(driver-name=postgresql,driver-module-name=com.postgresql,driver-xa-datasource-class-name=org.postgresql.xa.PGXADataSource)" | log

            # Create data source with ha profile
            echo "data-source add --profile=ha --driver-name=postgresql --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --user-name=${databaseUser} --password=*** --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLExceptionSorter" | log
            sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --controller=$(hostname -I) --echo-command \
            "data-source add --driver-name=postgresql --profile=ha --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --user-name=${databaseUser} --password=${databasePassword} --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLExceptionSorter"
        fi

else
    # Create JDBC driver and module directory
    jdbcDriverModuleDirectory="$eapRootPath"/modules/com/postgresql/main
    mkdir -p "$jdbcDriverModuleDirectory"

    # Download JDBC driver
    jdbcDriverName=postgresql-${jdbcDriverVersion}.jar
    curl --retry 5 -Lo ${jdbcDriverModuleDirectory}/${jdbcDriverName} https://jdbc.postgresql.org/download/${jdbcDriverName}

    # Create module for JDBC driver
    jdbcDriverModule=module.xml
    cat <<EOF >${jdbcDriverModule}
<?xml version="1.0" ?>
<module xmlns="urn:jboss:module:1.1" name="com.postgresql">
  <resources>
    <resource-root path="${jdbcDriverName}"/>
  </resources>
  <dependencies>
    <module name="javaee.api"/>
    <module name="sun.jdk"/>
    <module name="ibm.jdk"/>
    <module name="javax.api"/>
    <module name="javax.transaction.api"/>
  </dependencies>
</module>
EOF
    chmod 644 $jdbcDriverModule
    mv $jdbcDriverModule $jdbcDriverModuleDirectory/$jdbcDriverModule

    if [ $isManagedDomain == "false" ]; then
        # Register JDBC driver
        sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --echo-command \
        "/subsystem=datasources/jdbc-driver=postgresql:add(driver-name=postgresql,driver-module-name=com.postgresql,driver-xa-datasource-class-name=org.postgresql.xa.PGXADataSource)" | log

        # Create data source
        echo "data-source add --driver-name=postgresql --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --user-name=${databaseUser} --password=*** --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLExceptionSorter" | log
        sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --echo-command \
        "data-source add --driver-name=postgresql --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --user-name=${databaseUser} --password=${databasePassword} --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLExceptionSorter"
    elif [ $isSlaveServer == "false" ]; then
        # Register JDBC driver with ha profile
        sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --controller=$(hostname -I) --echo-command \
        "/profile=ha/subsystem=datasources/jdbc-driver=postgresql:add(driver-name=postgresql,driver-module-name=com.postgresql,driver-xa-datasource-class-name=org.postgresql.xa.PGXADataSource)" | log

        # Create data source with ha profile
        echo "data-source add --profile=ha --driver-name=postgresql --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --user-name=${databaseUser} --password=*** --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLExceptionSorter" | log
        sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --controller=$(hostname -I) --echo-command \
        "data-source add --driver-name=postgresql --profile=ha --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --user-name=${databaseUser} --password=${databasePassword} --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLExceptionSorter"
    fi

fi