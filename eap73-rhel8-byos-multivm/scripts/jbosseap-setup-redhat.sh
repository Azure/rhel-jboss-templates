#!/bin/sh
log_info() {
    while IFS= read -r line; do
        printf '%s [INFO]%s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$line" >> /var/log/jbosseap.install.log;
    done
}
log_err() {
    while IFS= read -r line; do
        printf '%s [ERR]%s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$line" >> /var/log/jbosseap.install.log;
    done
}

openport() {
    port=$1

    echo "firewall-cmd --zone=public --add-port=$port/tcp  --permanent"  | log_info
    sudo firewall-cmd  --zone=public --add-port=$port/tcp  --permanent   2>log_err | log_info 
}

echo "Red Hat JBoss EAP Cluster Intallation Start " | log_info
/bin/date +%H:%M:%S  >> /var/log/jbosseap.install.log

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
JBOSS_EAP_PASSWORD=${10}
RHSM_USER=${11}
RHSM_PASSWORD=${12}
EAP_POOL=${13}
STORAGE_ACCOUNT_NAME=${14}
CONTAINER_NAME=${15}
STORAGE_ACCESS_KEY=$(echo "${16}" | openssl enc -d -base64)
RHEL_POOL=${17} # kept at the end because it is possible that customer won't provide this.
IP_ADDR=$(hostname -I)

echo "JBoss EAP admin user: " ${JBOSS_EAP_USER} | log_info
echo "JBoss EAP on RHEL version you selected : JBoss-EAP7.3-on-RHEL8.0" | log_info
echo "Storage Account Name: " ${STORAGE_ACCOUNT_NAME} | log_info
echo "Storage Container Name: " ${CONTAINER_NAME} | log_info
echo "RHSM_USER: " ${RHSM_USER} | log_info

echo "Folder where script is executing ${pwd}" | log_info

####################### Configuring firewall for ports
echo "Configure firewall for ports 8080, 9990, 45700, 7600" | log_info

openport 9999
openport 8443
openport 8009
openport 8080
openport 9990
openport 45700
openport 7600

echo "firewall-cmd --reload" | log_info
sudo firewall-cmd  --reload  2>log_err | log_info 

echo "iptables-save" | log_info
sudo iptables-save   2>log_err | log_info 
####################### 

echo "Initial JBoss EAP setup" | log_info
####################### Register to subscription Manager
echo "Register subscription manager" | log_info
echo "subscription-manager register --username $RHSM_USER --password RHSM_PASSWORD" | log_info
subscription-manager register --username $RHSM_USER --password $RHSM_PASSWORD >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Red Hat Manager Registration Failed" | log_info; exit $flag;  fi
#######################

sleep 20

####################### Attach EAP Pool
echo "Subscribing the system to get access to JBoss EAP repos" | log_info
echo "subscription-manager attach --pool=EAP_POOL" | log_info
subscription-manager attach --pool=${EAP_POOL} >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Pool Attach for JBoss EAP Failed" | log_info; exit $flag;  fi
#######################

####################### Attach RHEL Pool
echo "Attaching Pool ID for RHEL OS" | log_info
echo "subscription-manager attach --pool=RHEL_POOL" | adddate  >> /var/log/jbosseap.install.log
subscription-manager attach --pool=${RHEL_POOL} >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Pool Attach for RHEL Failed" | log_info; exit $flag;  fi
#######################


####################### Install openjdk: is it needed? it should be installed with eap7.3
echo "Install openjdk, wget, git, unzip, vim" | log_info
echo "sudo yum install java-1.8.0-openjdk wget unzip vim git -y" | log_info
sudo yum install wget unzip vim git -y 2>log_err | log_info  #java-1.8.0-openjdk
####################### 


####################### Install JBoss EAP 7.3
echo "subscription-manager repos --enable=jb-eap-7.3-for-rhel-8-x86_64-rpms" | log_info
subscription-manager repos --enable=jb-eap-7.3-for-rhel-8-x86_64-rpms >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Enabling repos for JBoss EAP Failed" | log_info; exit $flag;  fi

echo "Installing JBoss EAP 7.3 repos" | log_info
echo "yum groupinstall -y jboss-eap7" | log_info
yum groupinstall -y jboss-eap7 >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP installation Failed" | log_info; exit $flag;  fi

echo "sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config" | log_info
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config 2>log_err | log_info 
echo "echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config" | log_info
echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config 2>log_err | log_info 
####################### 

echo "systemctl restart sshd" | log_info
systemctl restart sshd 2>log_err | log_info 

echo "Copy the standalone-azure-ha.xml from EAP_HOME/doc/wildfly/examples/configs folder to EAP_HOME/wildfly/standalone/configuration folder" | log_info
echo "cp $EAP_HOME/doc/wildfly/examples/configs/standalone-azure-ha.xml $EAP_HOME/wildfly/standalone/configuration/" | log_info
sudo -u jboss cp $EAP_HOME/doc/wildfly/examples/configs/standalone-azure-ha.xml $EAP_HOME/wildfly/standalone/configuration/ 2>log_err | log_info 

echo "Updating standalone-azure-ha.xml" | log_info
echo -e "\t stack UDP to TCP"           | log_info
echo -e "\t management:inet-address"    | log_info
echo -e "\t public:inet-address"        | log_info

sudo -u jboss $EAP_HOME/wildfly/bin/jboss-cli.sh --echo-command \
'embed-server --std-out=echo  --server-config=standalone-azure-ha.xml',\
'/subsystem=jgroups/channel=ee:write-attribute(name="stack", value="tcp")',\
'/interface=management:write-attribute(name=inet-address, value="${jboss.bind.address.management:0.0.0.0}")',\
'/interface=public:write-attribute(name=inet-address, value="${jboss.bind.address:0.0.0.0}")' 2>log_err | log_info 

####################### Configure the JBoss server and setup eap service
echo "Setting configurations in $EAP_RPM_CONF_STANDALONE"
echo -e "\t-> WILDFLY_SERVER_CONFIG=standalone-azure-ha.xml" | log_info 
echo 'WILDFLY_SERVER_CONFIG=standalone-azure-ha.xml' >> $EAP_RPM_CONF_STANDALONE 2>log_err | log_info

echo -e "\t-> WILDFLY_OPTS=-Djboss.bind.address.management=0.0.0.0" | log_info 
echo 'WILDFLY_OPTS="-Djboss.bind.address.management=0.0.0.0"' >> $EAP_RPM_CONF_STANDALONE 2>log_err | log_info

echo "Setting configurations in $EAP_LAUNCH_CONFIG"
echo -e '\t-> JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address.management=$(hostname -I)"' | log_info 
echo 'JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address.management=$(hostname -I)"' >> $EAP_LAUNCH_CONFIG 2>log_err | log_info

echo -e "JAVA_OPTS=\"\$JAVA_OPTS -Djboss.jgroups.azure_ping.storage_account_name=$STORAGE_ACCOUNT_NAME\"" >> $EAP_LAUNCH_CONFIG | log_info 
echo -e "JAVA_OPTS=\"\$JAVA_OPTS -Djboss.jgroups.azure_ping.storage_access_key=$STORAGE_ACCESS_KEY\"" >> $EAP_LAUNCH_CONFIG | log_info 
echo -e "JAVA_OPTS=\"\$JAVA_OPTS -Djboss.jgroups.azure_ping.container=$CONTAINER_NAME\"" >> $EAP_LAUNCH_CONFIG | log_info 
echo -e "JAVA_OPTS=\"\$JAVA_OPTS -Djava.net.preferIPv4Stack=true\"" >> $EAP_LAUNCH_CONFIG | log_info 
####################### Start the JBoss server and setup eap service
echo "Start JBoss-EAP service"                  | log_info
echo "systemctl enable eap7-standalone.service" | log_info
systemctl enable eap7-standalone.service        2>log_err | log_info 

echo "systemctl restart eap7-standalone.service"| log_info
systemctl restart eap7-standalone.service       2>log_err | log_info 
echo "systemctl status eap7-standalone.service" | log_info
systemctl status eap7-standalone.service        2>log_err | log_info 
####################### 

echo "Deploy an application" | log_info
echo "wget -O eap-session-replication.war $fileUrl" | log_info
wget -O "eap-session-replication.war" "$fileUrl" >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Sample Application Download Failed" | log_info; exit $flag; fi
echo "cp ./eap-session-replication.war $EAP_HOME/wildfly/standalone/deployments/" | log_info
cp ./eap-session-replication.war $EAP_HOME/wildfly/standalone/deployments/ 2>log_err | log_info
echo "touch $EAP_HOME/wildfly/standalone/deployments/eap-session-replication.war.dodeploy" | log_info
touch $EAP_HOME/wildfly/standalone/deployments/eap-session-replication.war.dodeploy 2>log_err | log_info 

echo "Configuring JBoss EAP management user..." | log_info
echo "$EAP_HOME/wildfly/bin/add-user.sh -u JBOSS_EAP_USER -p JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup'" | log_info
$EAP_HOME/wildfly/bin/add-user.sh  -u $JBOSS_EAP_USER -p $JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup' >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP management user configuration Failed" | log_info; exit $flag;  fi

# Seeing a race condition timing error so sleep to delay
sleep 20

echo "Red Hat JBoss EAP Cluster Intallation End " | log_info
/bin/date +%H:%M:%S  >> /var/log/jbosseap.install.log