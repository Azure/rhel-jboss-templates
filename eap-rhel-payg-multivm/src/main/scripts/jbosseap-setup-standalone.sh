#!/bin/sh
log() {
    while IFS= read -r line; do
        printf '%s %s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$line" >> /var/log/jbosseap.install.log
    done
}

openport() {
    port=$1

    echo "firewall-cmd --zone=public --add-port=$port/tcp  --permanent" | log; flag=${PIPESTATUS[0]}
    sudo firewall-cmd  --zone=public --add-port=$port/tcp  --permanent  | log; flag=${PIPESTATUS[0]}
}

## Update JBoss EAP to use latest patch.
# WALinuxAgent packages need to be excluded from update as it will stop the azure vm extension execution.
sudo yum update -y --exclude=WALinuxAgent | log; flag=${PIPESTATUS[0]}

# firewalld installation and configuration
if ! rpm -qa | grep firewalld 2>&1 > /dev/null ; then
    sudo yum update -y --disablerepo='*' --enablerepo='*microsoft*' | log; flag=${PIPESTATUS[0]}
    sudo yum install firewalld -y | log; flag=${PIPESTATUS[0]}
    sudo systemctl start firewalld
    sudo systemctl enable firewalld
fi

echo "Red Hat JBoss EAP Cluster Intallation Start " | log; flag=${PIPESTATUS[0]}
/bin/date +%H:%M:%S | log; flag=${PIPESTATUS[0]}

while getopts "a:t:p:f:" opt; do
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
    esac
done

fileUrl="$artifactsLocation$pathToFile/$fileToDownload$token"

JBOSS_EAP_USER=$9
JBOSS_EAP_PASSWORD_BASE64=${10}
JBOSS_EAP_PASSWORD=$(echo $JBOSS_EAP_PASSWORD_BASE64 | base64 -d)
JDK_VERSION=${11}
STORAGE_ACCOUNT_NAME=${12}
CONTAINER_NAME=${13}
STORAGE_ACCESS_KEY=${14}
CONNECT_SATELLITE=${15}
SATELLITE_ACTIVATION_KEY_BASE64=${16}
SATELLITE_ACTIVATION_KEY=$(echo $SATELLITE_ACTIVATION_KEY_BASE64 | base64 -d)
SATELLITE_ORG_NAME_BASE64=${17}
SATELLITE_ORG_NAME=$(echo $SATELLITE_ORG_NAME_BASE64 | base64 -d)
SATELLITE_VM_FQDN=${18}
enableDB=${19}
dbType=${20}
jdbcDSJNDIName=${21}
dsConnectionString=${22}
databaseUser=${23}
databasePassword=${24}
gracefulShutdownTimeout=${25}
enablePswlessConnection=${26}
uamiClientId=${27}

NODE_ID=$(uuidgen | sed 's/-//g' | cut -c 1-23)
HOST_VM_NAME=$(hostname)
HOST_VM_NAME_LOWERCASES=$(echo "${HOST_VM_NAME,,}")

echo "JBoss EAP admin user: " ${JBOSS_EAP_USER} | log; flag=${PIPESTATUS[0]}
echo "JBoss EAP on RHEL version you selected : JBoss-EAP7.4-on-RHEL8.4" | log; flag=${PIPESTATUS[0]}
echo "Storage Account Name: " ${STORAGE_ACCOUNT_NAME} | log; flag=${PIPESTATUS[0]}
echo "Storage Container Name: " ${CONTAINER_NAME} | log; flag=${PIPESTATUS[0]}

echo "Folder where script is executing ${pwd}" | log; flag=${PIPESTATUS[0]}

##################### Configure EAP_LAUNCH_CONFIG and EAP_HOME
if [[ "${JDK_VERSION,,}" == "eap8-openjdk17" || "${JDK_VERSION,,}" == "eap8-openjdk11" ]]; then

    export EAP_LAUNCH_CONFIG="/opt/rh/eap8/root/usr/share/wildfly/bin/standalone.conf"
    echo 'export EAP_RPM_CONF_STANDALONE="/etc/opt/rh/eap8/wildfly/eap8-standalone.conf"' >> ~/.bash_profile
    echo 'export EAP_HOME="/opt/rh/eap8/root/usr/share/wildfly"' >> ~/.bash_profile
    source ~/.bash_profile
    touch /etc/profile.d/eap_env.sh
    echo 'export EAP_HOME="/opt/rh/eap8/root/usr/share/wildfly"' >> /etc/profile.d/eap_env.sh

else
    export EAP_LAUNCH_CONFIG="/opt/rh/eap7/root/usr/share/wildfly/bin/standalone.conf"
    echo 'export EAP_RPM_CONF_STANDALONE="/etc/opt/rh/eap7/wildfly/eap7-standalone.conf"' >> ~/.bash_profile
    echo 'export EAP_HOME="/opt/rh/eap7/root/usr/share/wildfly"' >> ~/.bash_profile
    source ~/.bash_profile
    touch /etc/profile.d/eap_env.sh
    echo 'export EAP_HOME="/opt/rh/eap7/root/usr/share/wildfly"' >> /etc/profile.d/eap_env.sh
fi

####################### Configuring firewall for ports
echo "Configure firewall for ports 8080, 9990, 45700, 7600" | log; flag=${PIPESTATUS[0]}

openport 9999
openport 8443
openport 8009
openport 8080
openport 9990
openport 9993
openport 45700
openport 7600

echo "firewall-cmd --reload" | log; flag=${PIPESTATUS[0]}
sudo firewall-cmd  --reload  | log; flag=${PIPESTATUS[0]}

echo "iptables-save" | log; flag=${PIPESTATUS[0]}
sudo iptables-save   | log; flag=${PIPESTATUS[0]}
####################### 

echo "Initial JBoss EAP setup" | log; flag=${PIPESTATUS[0]}

# Satellite server configuration
if [[ "${CONNECT_SATELLITE,,}" == "true" ]]; then
    ####################### Register to satellite server
    echo "Configuring Satellite server registration" | log; flag=${PIPESTATUS[0]}

    echo "sudo rpm -Uvh http://${SATELLITE_VM_FQDN}/pub/katello-ca-consumer-latest.noarch.rpm" | log; flag=${PIPESTATUS[0]}
    sudo rpm -Uvh http://${SATELLITE_VM_FQDN}/pub/katello-ca-consumer-latest.noarch.rpm | log; flag=${PIPESTATUS[0]}

    echo "sudo subscription-manager clean" | log; flag=${PIPESTATUS[0]}
    sudo subscription-manager clean | log; flag=${PIPESTATUS[0]}

    echo "sudo subscription-manager register --org=${SATELLITE_ORG_NAME} --activationkey=${SATELLITE_ACTIVATION_KEY}" | log; flag=${PIPESTATUS[0]}
    sudo subscription-manager register --org="${SATELLITE_ORG_NAME}" --activationkey="${SATELLITE_ACTIVATION_KEY}" --force | log; flag=${PIPESTATUS[0]}
fi

####################### Install openjdk: is it needed? it should be installed with eap7.4
echo "Install openjdk, curl, wget, git, unzip, vim" | log; flag=${PIPESTATUS[0]}
echo "sudo yum install curl wget unzip vim git -y" | log; flag=${PIPESTATUS[0]}
sudo yum install curl wget unzip vim git -y | log; flag=${PIPESTATUS[0]}
####################### 

# workaround to this issue:https://github.com/azure-javaee/rhel-jboss-templates/issues/2
sudo update-crypto-policies --set DEFAULT:SHA1 | log; flag=${PIPESTATUS[0]}

## Set the right JDK version on the instance
if [[ "${JDK_VERSION,,}" == "eap8-openjdk17" || "${JDK_VERSION,,}" == "eap74-openjdk17" ]]; then
    echo "sudo alternatives --set java java-17-openjdk.x86_64" | log; flag=${PIPESTATUS[0]}
    sudo alternatives --set java java-17-openjdk.x86_64| log; flag=${PIPESTATUS[0]}
elif [[ "${JDK_VERSION,,}" == "eap8-openjdk11" || "${JDK_VERSION,,}" == "eap74-openjdk11" ]]; then
    echo "sudo alternatives --set java java-11-openjdk.x86_64" | log; flag=${PIPESTATUS[0]}
    sudo alternatives --set java java-11-openjdk.x86_64 | log; flag=${PIPESTATUS[0]}
elif [[ "${JDK_VERSION,,}" == "eap74-openjdk8" ]]; then
    echo "sudo alternatives --set java java-1.8.0-openjdk.x86_64" | log; flag=${PIPESTATUS[0]}
    sudo alternatives --set java java-1.8.0-openjdk.x86_64 | log; flag=${PIPESTATUS[0]}
fi
#######################
echo "Copy the standalone-azure-ha.xml from EAP_HOME/docs/examples/configs folder to EAP_HOME/standalone/configuration folder" | log; flag=${PIPESTATUS[0]}
echo "cp $EAP_HOME/docs/examples/configs/standalone-azure-ha.xml $EAP_HOME/standalone/configuration/" | log; flag=${PIPESTATUS[0]}
sudo -u jboss cp $EAP_HOME/docs/examples/configs/standalone-azure-ha.xml $EAP_HOME/standalone/configuration/ | log; flag=${PIPESTATUS[0]}

echo "Updating standalone-azure-ha.xml" | log; flag=${PIPESTATUS[0]}
echo -e "\t stack UDP to TCP"           | log; flag=${PIPESTATUS[0]}
echo -e "\t management:inet-address"    | log; flag=${PIPESTATUS[0]}
echo -e "\t public:inet-address"        | log; flag=${PIPESTATUS[0]}
echo -e "\t set transaction id"         | log; flag=${PIPESTATUS[0]}

## OpenJDK 17 specific logic
if [[ "${JDK_VERSION,,}" == "eap74-openjdk17" ]]; then
    sudo -u jboss $EAP_HOME/bin/jboss-cli.sh --file=$EAP_HOME/docs/examples/enable-elytron-se17.cli -Dconfig=standalone-azure-ha.xml
fi

sudo -u jboss $EAP_HOME/bin/jboss-cli.sh --echo-command \
'embed-server --std-out=echo  --server-config=standalone-azure-ha.xml',\
'/subsystem=transactions:write-attribute(name=node-identifier,value="'${NODE_ID}'")',\
'/subsystem=jgroups/channel=ee:write-attribute(name="stack", value="tcp")',\
'/interface=public:write-attribute(name=inet-address, value="${jboss.bind.address:0.0.0.0}")' | log; flag=${PIPESTATUS[0]}

####################### Configure the JBoss server and setup eap service
echo "Setting configurations in $EAP_RPM_CONF_STANDALONE"
echo -e "\t-> WILDFLY_SERVER_CONFIG=standalone-azure-ha.xml" | log; flag=${PIPESTATUS[0]}
echo 'WILDFLY_SERVER_CONFIG=standalone-azure-ha.xml' >> $EAP_RPM_CONF_STANDALONE | log; flag=${PIPESTATUS[0]}
echo 'WILDFLY_OPTS=-Dorg.wildfly.sigterm.suspend.timeout=${gracefulShutdownTimeout}' >> $EAP_RPM_CONF_STANDALONE | log; flag=${PIPESTATUS[0]}

echo "Setting configurations in $EAP_LAUNCH_CONFIG"
echo -e '\t-> JAVA_OPTS=$JAVA_OPTS -Djboss.bind.address=0.0.0.0' | log; flag=${PIPESTATUS[0]}
echo -e '\t-> JAVA_OPTS=$JAVA_OPTS -Djboss.bind.address.management=0.0.0.0' | log; flag=${PIPESTATUS[0]}
echo -e '\t-> JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address.private=$(hostname -I)"' | log; flag=${PIPESTATUS[0]}

echo -e 'JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address=0.0.0.0"' >> $EAP_LAUNCH_CONFIG | log; flag=${PIPESTATUS[0]}
echo -e 'JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address.management=0.0.0.0"' >> $EAP_LAUNCH_CONFIG | log; flag=${PIPESTATUS[0]}
echo -e 'JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address.private=$(hostname -I)"' >> $EAP_LAUNCH_CONFIG | log; flag=${PIPESTATUS[0]}
echo -e 'JAVA_OPTS="$JAVA_OPTS -Djava.net.preferIPv4Stack=true"' >> $EAP_LAUNCH_CONFIG | log; flag=${PIPESTATUS[0]}

echo -e "JAVA_OPTS=\"\$JAVA_OPTS -Djboss.jgroups.azure_ping.storage_account_name=$STORAGE_ACCOUNT_NAME\"" >> $EAP_LAUNCH_CONFIG | log; flag=${PIPESTATUS[0]}
echo -e "JAVA_OPTS=\"\$JAVA_OPTS -Djboss.jgroups.azure_ping.storage_access_key=$STORAGE_ACCESS_KEY\"" >> $EAP_LAUNCH_CONFIG | log; flag=${PIPESTATUS[0]}
echo -e "JAVA_OPTS=\"\$JAVA_OPTS -Djboss.jgroups.azure_ping.container=$CONTAINER_NAME\"" >> $EAP_LAUNCH_CONFIG | log; flag=${PIPESTATUS[0]}
####################### Start the JBoss server and setup eap service

if [[ "${JDK_VERSION,,}" == "eap8-openjdk17" || "${JDK_VERSION,,}" == "eap8-openjdk11" ]]; then
    echo "Start JBoss-EAP service"                  | log; flag=${PIPESTATUS[0]}
    echo "systemctl enable eap8-standalone.service" | log; flag=${PIPESTATUS[0]}
    systemctl enable eap8-standalone.service        | log; flag=${PIPESTATUS[0]}

    ###################### Editing eap8-standalone.services
    echo "Adding - After=syslog.target network.target NetworkManager-wait-online.service" | log; flag=${PIPESTATUS[0]}
    sed -i 's/After=syslog.target network.target/After=syslog.target network.target NetworkManager-wait-online.service/' /usr/lib/systemd/system/eap8-standalone.service | log; flag=${PIPESTATUS[0]}
    echo "Adding - Wants=NetworkManager-wait-online.service \nBefore=httpd.service" | log; flag=${PIPESTATUS[0]}
    sed -i 's/Before=httpd.service/Wants=NetworkManager-wait-online.service \nBefore=httpd.service/' /usr/lib/systemd/system/eap8-standalone.service | log; flag=${PIPESTATUS[0]}
    # Calculating EAP gracefulShutdownTimeout and passing it the service.
    if  [[ "${gracefulShutdownTimeout,,}" == "-1" ]]; then
        sed -i 's/Environment="WILDFLY_OPTS="/Environment="WILDFLY_OPTS="\nTimeoutStopSec=infinity/' /usr/lib/systemd/system/eap8-standalone.service | log; flag=${PIPESTATUS[0]}
    else
        timeoutStopSec=$gracefulShutdownTimeout+20
        if  "${timeoutStopSec}">90; then
        sed -i 's/Environment="WILDFLY_OPTS="/Environment="WILDFLY_OPTS="\nTimeoutStopSec='${timeoutStopSec}'/' /usr/lib/systemd/system/eap8-standalone.service | log; flag=${PIPESTATUS[0]}
        fi
    fi
    systemd-analyze verify --recursive-errors=no /usr/lib/systemd/system/eap8-standalone.service
    echo "systemctl daemon-reload" | log; flag=${PIPESTATUS[0]}
    systemctl daemon-reload | log; flag=${PIPESTATUS[0]}

    echo "systemctl restart eap8-standalone.service"| log; flag=${PIPESTATUS[0]}
    systemctl restart eap8-standalone.service       | log; flag=${PIPESTATUS[0]}
    echo "systemctl status eap8-standalone.service" | log; flag=${PIPESTATUS[0]}
    systemctl status eap8-standalone.service        | log; flag=${PIPESTATUS[0]}

else
    ####################### Start the JBoss server and setup eap service
    echo "Start JBoss-EAP service"                  | log; flag=${PIPESTATUS[0]}
    echo "systemctl enable eap7-standalone.service" | log; flag=${PIPESTATUS[0]}
    systemctl enable eap7-standalone.service        | log; flag=${PIPESTATUS[0]}
    #######################

    ###################### Editing eap7-standalone.services
    echo "Adding - After=syslog.target network.target NetworkManager-wait-online.service" | log; flag=${PIPESTATUS[0]}
    sed -i 's/After=syslog.target network.target/After=syslog.target network.target NetworkManager-wait-online.service/' /usr/lib/systemd/system/eap7-standalone.service | log; flag=${PIPESTATUS[0]}
    echo "Adding - Wants=NetworkManager-wait-online.service \nBefore=httpd.service" | log; flag=${PIPESTATUS[0]}
    sed -i 's/Before=httpd.service/Wants=NetworkManager-wait-online.service \nBefore=httpd.service/' /usr/lib/systemd/system/eap7-standalone.service | log; flag=${PIPESTATUS[0]}
    # Calculating EAP gracefulShutdownTimeout and passing it the service.
    if  [[ "${gracefulShutdownTimeout,,}" == "-1"  ]]; then
        sed -i 's/Environment="WILDFLY_OPTS="/Environment="WILDFLY_OPTS="\nTimeoutStopSec=infinity/' /usr/lib/systemd/system/eap7-standalone.service | log; flag=${PIPESTATUS[0]}
    else
        timeoutStopSec=$gracefulShutdownTimeout+20
        if  "${timeoutStopSec}">90; then
        sed -i 's/Environment="WILDFLY_OPTS="/Environment="WILDFLY_OPTS="\nTimeoutStopSec='${timeoutStopSec}'/' /usr/lib/systemd/system/eap7-standalone.service | log; flag=${PIPESTATUS[0]}
        fi
    fi
    systemd-analyze verify --recursive-errors=no /usr/lib/systemd/system/eap7-standalone.service
    echo "systemctl daemon-reload" | log; flag=${PIPESTATUS[0]}
    systemctl daemon-reload | log; flag=${PIPESTATUS[0]}

    echo "systemctl restart eap7-standalone.service"| log; flag=${PIPESTATUS[0]}
    systemctl restart eap7-standalone.service       | log; flag=${PIPESTATUS[0]}
    echo "systemctl status eap7-standalone.service" | log; flag=${PIPESTATUS[0]}
    systemctl status eap7-standalone.service        | log; flag=${PIPESTATUS[0]}
    ######################
fi

echo "Deploy an application" | log; flag=${PIPESTATUS[0]}
echo "curl -o eap-session-replication.war $fileUrl" | log; flag=${PIPESTATUS[0]}
curl -o "eap-session-replication.war" "$fileUrl" | log; flag=${PIPESTATUS[0]}
if [ $flag != 0 ] ; then echo  "ERROR! Sample Application Download Failed" >&2 log; exit $flag; fi
echo "cp ./eap-session-replication.war $EAP_HOME/standalone/deployments/" | log; flag=${PIPESTATUS[0]}
cp ./eap-session-replication.war $EAP_HOME/standalone/deployments/ | log; flag=${PIPESTATUS[0]}
echo "touch $EAP_HOME/standalone/deployments/eap-session-replication.war.dodeploy" | log; flag=${PIPESTATUS[0]}
touch $EAP_HOME/standalone/deployments/eap-session-replication.war.dodeploy | log; flag=${PIPESTATUS[0]}

echo "Configuring JBoss EAP management user..." | log; flag=${PIPESTATUS[0]}
echo "$EAP_HOME/bin/add-user.sh -u JBOSS_EAP_USER -p JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup'" | log; flag=${PIPESTATUS[0]}
$EAP_HOME/bin/add-user.sh  -u $JBOSS_EAP_USER -p $JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup' | log; flag=${PIPESTATUS[0]}
if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP management user configuration Failed" >&2 log; exit $flag;  fi

# Seeing a race condition timing error so sleep to delay
sleep 20

# Configure JDBC driver and data source
if [ "$enableDB" == "True" ]; then
    echo "Start to configure JDBC driver and data source" | log
    jdbcDataSourceName=dataSource-$dbType
    ./create-ds-${dbType}.sh $EAP_HOME "$jdbcDataSourceName" "$jdbcDSJNDIName" "$dsConnectionString" "$databaseUser" "$databasePassword" false false $enablePswlessConnection "$uamiClientId"

    # Test connection for the created data source
    sudo -u jboss $EAP_HOME/bin/jboss-cli.sh --connect "/subsystem=datasources/data-source=$jdbcDataSourceName:test-connection-in-pool" | log; flag=${PIPESTATUS[0]}
    if [ $flag != 0 ]; then
        echo "ERROR! Test data source connection failed." >&2 log
        exit $flag
    fi
    echo "Complete to configure JDBC driver and data source" | log
fi

echo "Red Hat JBoss EAP Cluster Intallation End " | log; flag=${PIPESTATUS[0]}
/bin/date +%H:%M:%S | log