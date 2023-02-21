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

JBOSS_EAP_USER=$1
JBOSS_EAP_PASSWORD_BASE64=$2
JBOSS_EAP_PASSWORD=$(echo $JBOSS_EAP_PASSWORD_BASE64 | base64 -d)
RHSM_USER=$3
RHSM_PASSWORD_BASE64=$4
RHSM_PASSWORD=$(echo $RHSM_PASSWORD_BASE64 | base64 -d)
RHSM_EAPPOOL=$5
CONNECT_SATELLITE=${6}
SATELLITE_ACTIVATION_KEY_BASE64=${7}
SATELLITE_ACTIVATION_KEY=$(echo $SATELLITE_ACTIVATION_KEY_BASE64 | base64 -d)
SATELLITE_ORG_NAME_BASE64=${8}
SATELLITE_ORG_NAME=$(echo $SATELLITE_ORG_NAME_BASE64 | base64 -d)
SATELLITE_VM_FQDN=${9}
JDK_VERSION=${10}
enableDB=${11}
dbType=${12}
jdbcDSJNDIName=${13}
dsConnectionString=${14}
databaseUser=${15}
databasePassword=${16}
NODE_ID=$(uuidgen | sed 's/-//g' | cut -c 1-23)

export EAP_HOME="/opt/rh/eap7/root/usr/share/wildfly"
export EAP_RPM_CONF_STANDALONE="/etc/opt/rh/eap7/wildfly/eap7-standalone.conf"
export EAP_LAUNCH_CONFIG="/opt/rh/eap7/root/usr/share/wildfly/bin/standalone.conf"

echo 'export EAP_HOME="/opt/rh/eap7/root/usr/share/wildfly"' >> ~/.bash_profile
echo 'export EAP_RPM_CONF_STANDALONE="/etc/opt/rh/eap7/wildfly/eap7-standalone.conf"' >> ~/.bash_profile
source ~/.bash_profile
touch /etc/profile.d/eap_env.sh
echo 'export EAP_HOME="/opt/rh/eap7/root/usr/share/wildfly"' >> /etc/profile.d/eap_env.sh
echo 'export EAP_RPM_CONF_STANDALONE="/etc/opt/rh/eap7/wildfly/eap7-standalone.conf"' >> /etc/profile.d/eap_env.sh

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
else
    echo "Initial JBoss EAP 7.4 setup" | log; flag=${PIPESTATUS[0]}
    echo "subscription-manager register --username RHSM_USER --password RHSM_PASSWORD" | log; flag=${PIPESTATUS[0]}
    subscription-manager register --username $RHSM_USER --password $RHSM_PASSWORD --force | log; flag=${PIPESTATUS[0]}
    if [ $flag != 0 ] ; then echo  "ERROR! Red Hat Subscription Manager Registration Failed" >&2 log; exit $flag;  fi

    echo "Subscribing the system to get access to JBoss EAP 7.4 repos" | log; flag=${PIPESTATUS[0]}
    echo "subscription-manager attach --pool=EAP_POOL" | log; flag=${PIPESTATUS[0]}
    subscription-manager attach --pool=${RHSM_EAPPOOL} | log; flag=${PIPESTATUS[0]}
    if [ $flag != 0 ] ; then echo  "ERROR! Pool Attach for JBoss EAP Failed" >&2 log; exit $flag;  fi
fi

####################### Install openjdk, EAP 7.4 is shipped with JDK 1.8, we are allowing more
echo "Install openjdk, curl, wget, git, unzip, vim" | log; flag=${PIPESTATUS[0]}
echo "sudo yum install curl wget unzip vim git -y" | log; flag=${PIPESTATUS[0]}
sudo yum install curl wget unzip vim git -y | log; flag=${PIPESTATUS[0]}
## Install specific JDK version
if [[ "${JDK_VERSION,,}" == "openjdk17" ]]; then
    echo "sudo yum install java-17-openjdk -y" | log; flag=${PIPESTATUS[0]}
    sudo yum install java-17-openjdk -y | log; flag=${PIPESTATUS[0]}
elif [[ "${JDK_VERSION,,}" == "openjdk11" ]]; then
    echo "sudo yum install java-11-openjdk -y" | log; flag=${PIPESTATUS[0]}
    sudo yum install java-11-openjdk -y | log; flag=${PIPESTATUS[0]}
elif [[ "${JDK_VERSION,,}" == "openjdk8" ]]; then
    echo "openjdk8 is shipped with EAP 7.4, proceed" | log; flag=${PIPESTATUS[0]}
fi
####################### 

# Install JBoss EAP 7.4
echo "subscription-manager repos --enable=jb-eap-7.4-for-rhel-8-x86_64-rpms" | log; flag=${PIPESTATUS[0]}
subscription-manager repos --enable=jb-eap-7.4-for-rhel-8-x86_64-rpms | log; flag=${PIPESTATUS[0]}
if [ $flag != 0 ] ; then echo  "ERROR! Enabling repos for JBoss EAP Failed" >&2 log; exit $flag;  fi

echo "Installing JBoss EAP 7.4 repos" | log; flag=${PIPESTATUS[0]}
echo "yum groupinstall -y jboss-eap7" | log; flag=${PIPESTATUS[0]}
yum groupinstall -y jboss-eap7 | log; flag=${PIPESTATUS[0]}
if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP installation Failed" >&2 log; exit $flag;  fi

echo "Updating standalone-full-ha.xml" | log; flag=${PIPESTATUS[0]}
echo -e "\t stack UDP to TCP"  | log; flag=${PIPESTATUS[0]}
echo -e "\t set transaction id"     | log; flag=${PIPESTATUS[0]}

## OpenJDK 17 specific logic
if [[ "${JDK_VERSION,,}" == "openjdk17" ]]; then
    sudo -u jboss $EAP_HOME/bin/jboss-cli.sh --file=$EAP_HOME/docs/examples/enable-elytron-se17.cli -Dconfig=standalone-full-ha.xml
fi

sudo -u jboss $EAP_HOME/bin/jboss-cli.sh --echo-command \
'embed-server --std-out=echo  --server-config=standalone-full-ha.xml',\
'/subsystem=transactions:write-attribute(name=node-identifier,value="'${NODE_ID}'")',\
'/subsystem=jgroups/channel=ee:write-attribute(name="stack", value="tcp")' | log; flag=${PIPESTATUS[0]}

####################### Configure the JBoss server and setup eap service
echo "Setting configurations in $EAP_RPM_CONF_STANDALONE"
echo -e "\t-> WILDFLY_SERVER_CONFIG=standalone-full-ha.xml" | log; flag=${PIPESTATUS[0]}
echo 'WILDFLY_SERVER_CONFIG=standalone-full-ha.xml' >> $EAP_RPM_CONF_STANDALONE | log; flag=${PIPESTATUS[0]}

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
echo "Start JBoss-EAP service"                   | log; flag=${PIPESTATUS[0]}
echo "systemctl enable eap7-standalone.service"  | log; flag=${PIPESTATUS[0]}
systemctl enable eap7-standalone.service         | log; flag=${PIPESTATUS[0]}
####################### 

###################### Editing eap7-standalone.services and adding the following lines
echo "Adding - After=syslog.target network.target NetworkManager-wait-online.service" | log; flag=${PIPESTATUS[0]}
sed -i 's/After=syslog.target network.target/After=syslog.target network.target NetworkManager-wait-online.service/' /usr/lib/systemd/system/eap7-standalone.service | log; flag=${PIPESTATUS[0]}
echo "Adding - Wants=NetworkManager-wait-online.service \nBefore=httpd.service" | log; flag=${PIPESTATUS[0]}
sed -i 's/Before=httpd.service/Wants=NetworkManager-wait-online.service \nBefore=httpd.service/' /usr/lib/systemd/system/eap7-standalone.service | log; flag=${PIPESTATUS[0]}
echo "systemctl daemon-reload" | log; flag=${PIPESTATUS[0]}
systemctl daemon-reload

echo "systemctl restart eap7-standalone.service"| log; flag=${PIPESTATUS[0]}
systemctl restart eap7-standalone.service       | log; flag=${PIPESTATUS[0]}
echo "systemctl status eap7-standalone.service" | log; flag=${PIPESTATUS[0]}
systemctl status eap7-standalone.service        | log; flag=${PIPESTATUS[0]}
######################

openport 8080
openport 9990
openport 9999
openport 8443
openport 8009
openport 22
echo "firewall-cmd --reload"    | log; flag=${PIPESTATUS[0]}
firewall-cmd --reload           | log; flag=${PIPESTATUS[0]}
echo "iptables-save"            | log; flag=${PIPESTATUS[0]}
sudo iptables-save              | log; flag=${PIPESTATUS[0]}

/bin/date +%H:%M:%S | log; flag=${PIPESTATUS[0]}
echo "Configuring JBoss EAP management user" | log; flag=${PIPESTATUS[0]}
echo "$EAP_HOME/bin/add-user.sh -u JBOSS_EAP_USER -p JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup'" | log; flag=${PIPESTATUS[0]}
$EAP_HOME/bin/add-user.sh -u $JBOSS_EAP_USER -p $JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup' | log; flag=${PIPESTATUS[0]}

if [ $flag != 0 ]; then 
    echo  "ERROR! JBoss EAP management user configuration Failed" >&2 log; flag=${PIPESTATUS[0]}
    exit $flag;
fi 

# Seeing a race condition timing error so sleep to delay
sleep 20

# Configure JDBC driver and data source
if [ "$enableDB" == "True" ]; then
    jdbcDataSourceName=dataSource-$dbType
    ./create-ds.sh $EAP_HOME "$dbType" "$jdbcDataSourceName" "$jdbcDSJNDIName" "$dsConnectionString" "$databaseUser" "$databasePassword"

    # Test connection for the created data source
    sudo -u jboss $EAP_HOME/bin/jboss-cli.sh --connect "/subsystem=datasources/data-source=dataSource-$dbType:test-connection-in-pool" | log; flag=${PIPESTATUS[0]}
    if [ $flag != 0 ]; then 
        echo "ERROR! Test data source connection failed." >&2 log
        exit $flag
    fi
fi

echo "ALL DONE!" | log; flag=${PIPESTATUS[0]}
/bin/date +%H:%M:%S | log