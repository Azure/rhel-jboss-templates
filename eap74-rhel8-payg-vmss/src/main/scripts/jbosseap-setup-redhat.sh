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

echo "Red Hat JBoss EAP Cluster Intallation Start " | log; flag=${PIPESTATUS[0]}
/bin/date +%H:%M:%S  | log; flag=${PIPESTATUS[0]}

export EAP_LAUNCH_CONFIG="/opt/rh/eap7/root/usr/share/wildfly/bin/standalone.conf"
echo 'export EAP_RPM_CONF_STANDALONE="/etc/opt/rh/eap7/wildfly/eap7-standalone.conf"' >> ~/.bash_profile
echo 'export EAP_HOME="/opt/rh/eap7/root/usr/share"' >> ~/.bash_profile
source ~/.bash_profile
touch /etc/profile.d/eap_env.sh
echo 'export EAP_HOME="/opt/rh/eap7/root/usr/share"' >> /etc/profile.d/eap_env.sh

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
RHSM_USER=${11}
RHSM_PASSWORD_BASE64=${12}
RHSM_PASSWORD=$(echo $RHSM_PASSWORD_BASE64 | base64 -d)
RHSM_POOL=${13}
STORAGE_ACCOUNT_NAME=${14}
CONTAINER_NAME=${15}
STORAGE_ACCESS_KEY=$(echo "${16}" | openssl enc -d -base64)
CONNECT_SATELLITE=${17}
SATELLITE_ACTIVATION_KEY_BASE64=${18}
SATELLITE_ACTIVATION_KEY=$(echo $SATELLITE_ACTIVATION_KEY_BASE64 | base64 -d)
SATELLITE_ORG_NAME_BASE64=${19}
SATELLITE_ORG_NAME=$(echo $SATELLITE_ORG_NAME_BASE64 | base64 -d)
SATELLITE_VM_FQDN=${20}
NODE_ID=$(uuidgen | sed 's/-//g' | cut -c 1-23)

echo "JBoss EAP admin user: " ${JBOSS_EAP_USER} | log; flag=${PIPESTATUS[0]}
echo "JBoss EAP on RHEL version you selected : JBoss-EAP7.4-on-RHEL8.4" | log; flag=${PIPESTATUS[0]}
echo "Storage Account Name: " ${STORAGE_ACCOUNT_NAME} | log; flag=${PIPESTATUS[0]}
echo "Storage Container Name: " ${CONTAINER_NAME} | log; flag=${PIPESTATUS[0]}
echo "RHSM_USER: " ${RHSM_USER} | log; flag=${PIPESTATUS[0]}

####################### Configuring firewall for ports
echo "Configure firewall for ports 8080, 9990, 45700, 7600" | log; flag=${PIPESTATUS[0]}

openport 9999
openport 8443
openport 8009
openport 8080
openport 9990
openport 45700
openport 7600
echo "firewall-cmd --reload" | log; flag=${PIPESTATUS[0]}
sudo firewall-cmd  --reload| log; flag=${PIPESTATUS[0]}
echo "iptables-save" | log; flag=${PIPESTATUS[0]}
sudo iptables-save | log; flag=${PIPESTATUS[0]}
####################### 

# Satellite server configuration
echo "CONNECT_SATELLITE: ${CONNECT_SATELLITE}"
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
    echo "Initial JBoss EAP setup" | log; flag=${PIPESTATUS[0]}
    ####################### Register to subscription Manager
    echo "Register subscription manager" | log; flag=${PIPESTATUS[0]}
    echo "subscription-manager register --username RHSM_USER --password RHSM_PASSWORD" | log; flag=${PIPESTATUS[0]}
    subscription-manager register --username $RHSM_USER --password $RHSM_PASSWORD --force | log; flag=${PIPESTATUS[0]}
    if [ $flag != 0 ] ; then echo  "ERROR! Red Hat Manager Registration Failed" >&2 log; exit $flag;  fi
    #######################
    ####################### Attach EAP Pool
    echo "Subscribing the system to get access to JBoss EAP repos" | log; flag=${PIPESTATUS[0]}
    echo "subscription-manager attach --pool=EAP_POOL" | log; flag=${PIPESTATUS[0]}
    subscription-manager attach --pool=${RHSM_POOL} | log; flag=${PIPESTATUS[0]}
    if [ $flag != 0 ] ; then echo  "ERROR! Pool Attach for JBoss EAP Failed" >&2 log; exit $flag;  fi
    #######################
fi

####################### Install openjdk: is it needed? it should be installed with eap7.4
echo "Install openjdk, curl, wget, git, unzip, vim" | log; flag=${PIPESTATUS[0]}
echo "sudo yum install java-1.8.4-openjdk curl wget unzip vim git -y" | log; flag=${PIPESTATUS[0]}
sudo yum install curl wget unzip vim git -y | log; flag=${PIPESTATUS[0]}#java-1.8.4-openjdk
####################### 


####################### Install JBoss EAP 7.4
echo "subscription-manager repos --enable=jb-eap-7.4-for-rhel-8-x86_64-rpms" | log; flag=${PIPESTATUS[0]}
subscription-manager repos --enable=jb-eap-7.4-for-rhel-8-x86_64-rpms | log; flag=${PIPESTATUS[0]}
if [ $flag != 0 ] ; then echo  "ERROR! Enabling repos for JBoss EAP Failed" >&2 log; exit $flag;  fi

echo "Installing JBoss EAP 7.4 repos" | log; flag=${PIPESTATUS[0]}
echo "yum groupinstall -y jboss-eap7" | log; flag=${PIPESTATUS[0]}
yum groupinstall -y jboss-eap7 | log; flag=${PIPESTATUS[0]}
if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP installation Failed" >&2 log; exit $flag;  fi

echo "sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config" | log; flag=${PIPESTATUS[0]}
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config | log; flag=${PIPESTATUS[0]}
echo "echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config" | log; flag=${PIPESTATUS[0]}
echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config | log; flag=${PIPESTATUS[0]}
####################### 

echo "systemctl restart sshd" | log; flag=${PIPESTATUS[0]}
systemctl restart sshd | log; flag=${PIPESTATUS[0]}

echo "Copy the standalone-azure-ha.xml from EAP_HOME/doc/wildfly/examples/configs folder to EAP_HOME/wildfly/standalone/configuration folder" | log; flag=${PIPESTATUS[0]}
echo "cp $EAP_HOME/doc/wildfly/examples/configs/standalone-azure-ha.xml $EAP_HOME/wildfly/standalone/configuration/" | log; flag=${PIPESTATUS[0]}
sudo -u jboss cp $EAP_HOME/doc/wildfly/examples/configs/standalone-azure-ha.xml $EAP_HOME/wildfly/standalone/configuration/ | log; flag=${PIPESTATUS[0]}

echo "Updating standalone-azure-ha.xml" | log; flag=${PIPESTATUS[0]}
echo -e "\t stack UDP to TCP"         | log; flag=${PIPESTATUS[0]}
echo -e "\t set transaction id"       | log; flag=${PIPESTATUS[0]}

sudo -u jboss $EAP_HOME/wildfly/bin/jboss-cli.sh --echo-command \
'embed-server --std-out=echo  --server-config=standalone-azure-ha.xml',\
'/subsystem=transactions:write-attribute(name=node-identifier,value="'${NODE_ID}'")',\
'/subsystem=jgroups/channel=ee:write-attribute(name="stack", value="tcp")' | log; flag=${PIPESTATUS[0]}

####################### Configure the JBoss server and setup eap service
echo "Setting configurations in $EAP_RPM_CONF_STANDALONE"
echo -e "\t-> WILDFLY_SERVER_CONFIG=standalone-azure-ha.xml" | log; flag=${PIPESTATUS[0]}
echo 'WILDFLY_SERVER_CONFIG=standalone-azure-ha.xml' >> $EAP_RPM_CONF_STANDALONE | log; flag=${PIPESTATUS[0]}

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
echo "Start JBoss-EAP service"                | log; flag=${PIPESTATUS[0]}
echo "systemctl enable eap7-standalone.service" | log; flag=${PIPESTATUS[0]}
systemctl enable eap7-standalone.service      | log; flag=${PIPESTATUS[0]}
####################### 

###################### Editing eap7-standalone.services
echo "Adding - After=syslog.target network.target NetworkManager-wait-online.service" | log; flag=${PIPESTATUS[0]}
sed -i 's/After=syslog.target network.target/After=syslog.target network.target NetworkManager-wait-online.service/' /usr/lib/systemd/system/eap7-standalone.service
echo "Adding - Wants=NetworkManager-wait-online.service \nBefore=httpd.service" | log; flag=${PIPESTATUS[0]}
sed -i 's/Before=httpd.service/Wants=NetworkManager-wait-online.service \nBefore=httpd.service/' /usr/lib/systemd/system/eap7-standalone.service
echo "systemctl daemon-reload" | log; flag=${PIPESTATUS[0]}
systemctl daemon-reload

echo "systemctl restart eap7-standalone.service"| log; flag=${PIPESTATUS[0]}
systemctl restart eap7-standalone.service       | log; flag=${PIPESTATUS[0]}
echo "systemctl status eap7-standalone.service" | log; flag=${PIPESTATUS[0]}
systemctl status eap7-standalone.service        | log; flag=${PIPESTATUS[0]}
######################

echo "Deploy an application" | log; flag=${PIPESTATUS[0]}
echo "curl -o eap-session-replication.war $fileUrl" | log; flag=${PIPESTATUS[0]}
curl -o "eap-session-replication.war" "$fileUrl" | log; flag=${PIPESTATUS[0]}
if [ $flag != 0 ] ; then echo  "ERROR! Sample Application Download Failed" >&2 log; exit $flag; fi
echo "cp ./eap-session-replication.war $EAP_HOME/wildfly/standalone/deployments/" | log; flag=${PIPESTATUS[0]}
cp ./eap-session-replication.war $EAP_HOME/wildfly/standalone/deployments/ | log; flag=${PIPESTATUS[0]}
echo "touch $EAP_HOME/wildfly/standalone/deployments/eap-session-replication.war.dodeploy" | log; flag=${PIPESTATUS[0]}
touch $EAP_HOME/wildfly/standalone/deployments/eap-session-replication.war.dodeploy | log; flag=${PIPESTATUS[0]}

echo "Configuring JBoss EAP management user..." | log; flag=${PIPESTATUS[0]}
echo "$EAP_HOME/wildfly/bin/add-user.sh -u JBOSS_EAP_USER -p JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup'" | log; flag=${PIPESTATUS[0]}
$EAP_HOME/wildfly/bin/add-user.sh  -u $JBOSS_EAP_USER -p $JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup' | log; flag=${PIPESTATUS[0]}
if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP management user configuration Failed" >&2 log; exit $flag;  fi

# Seeing a race condition timing error so sleep to delay
sleep 20

echo "Red Hat JBoss EAP Cluster Intallation End " | log; flag=${PIPESTATUS[0]}
/bin/date +%H:%M:%S  | log