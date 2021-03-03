#!/bin/sh

adddate() {
    while IFS= read -r line; do
        printf '%s %s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$line";
    done
}

echo "Red Hat JBoss EAP Cluster Intallation Start " | adddate >> /var/log/jbosseap.install.log
/bin/date +%H:%M:%S  >> /var/log/jbosseap.install.log

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
RHSM_POOL=${13}  # have not passed rhel pool
RHEL_POOL=${14}
STORAGE_ACCOUNT_NAME=${15}
CONTAINER_NAME=${16}
STORAGE_ACCESS_KEY=$(echo "${17}" | openssl enc -d -base64)
IP_ADDR=$(hostname -I)

echo "JBoss EAP admin user: " ${JBOSS_EAP_USER} | adddate >> /var/log/jbosseap.install.log
echo "JBoss EAP on RHEL version you selected : JBoss-EAP7.3-on-RHEL8.0" | adddate >> /var/log/jbosseap.install.log
echo "Storage Account Name: " ${STORAGE_ACCOUNT_NAME} | adddate >> /var/log/jbosseap.install.log
echo "Storage Container Name: " ${CONTAINER_NAME} | adddate >> /var/log/jbosseap.install.log
echo "RHSM_USER: " ${RHSM_USER} | adddate >> /var/log/jbosseap.install.log

####################### Configuring firewall for ports
echo "Configure firewall for ports 8080, 9990, 45700, 7600" | adddate >> /var/log/jbosseap.install.log

echo "firewall-cmd --zone=public --add-port=8080/tcp  --permanent"  | adddate >> /var/log/jbosseap.install.log
sudo firewall-cmd  --zone=public --add-port=8080/tcp  --permanent   | adddate >> /var/log/jbosseap.install.log 2>&1
echo "firewall-cmd --zone=public --add-port=9990/tcp  --permanent"  | adddate >> /var/log/jbosseap.install.log
sudo firewall-cmd  --zone=public --add-port=9990/tcp  --permanent   | adddate >> /var/log/jbosseap.install.log 2>&1
echo "firewall-cmd --zone=public --add-port=45700/tcp --permanent" | adddate >> /var/log/jbosseap.install.log
sudo firewall-cmd  --zone=public --add-port=45700/tcp --permanent  | adddate >> /var/log/jbosseap.install.log 2>&1
echo "firewall-cmd --zone=public --add-port=7600/tcp  --permanent"  | adddate >> /var/log/jbosseap.install.log
sudo firewall-cmd  --zone=public --add-port=7600/tcp  --permanent   | adddate >> /var/log/jbosseap.install.log 2>&1
echo "firewall-cmd --reload" | adddate >> /var/log/jbosseap.install.log
sudo firewall-cmd  --reload  | adddate >> /var/log/jbosseap.install.log 2>&1
echo "iptables-save" | adddate >> /var/log/jbosseap.install.log
sudo iptables-save   | adddate >> /var/log/jbosseap.install.log 2>&1
####################### 

echo "Initial JBoss EAP setup" | adddate >> /var/log/jbosseap.install.log
####################### Register to subscription Manager
echo "Register subscription manager" | adddate >> /var/log/jbosseap.install.log
echo "subscription-manager register --username RHSM_USER --password RHSM_PASSWORD" | adddate >> /var/log/jbosseap.install.log
subscription-manager register --username $RHSM_USER --password $RHSM_PASSWORD >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Red Hat Manager Registration Failed" | adddate >> /var/log/jbosseap.install.log; exit $flag;  fi
#######################
####################### Attach EAP Pool
echo "Subscribing the system to get access to JBoss EAP repos" | adddate >> /var/log/jbosseap.install.log
echo "subscription-manager attach --pool=EAP_POOL" | adddate >> /var/log/jbosseap.install.log
subscription-manager attach --pool=${RHSM_POOL} >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Pool Attach for JBoss EAP Failed" | adddate >> /var/log/jbosseap.install.log; exit $flag;  fi
#######################
####################### Attach RHEL Pool
echo "Attaching Pool ID for RHEL OS" | adddate >> /var/log/jbosseap.install.log
echo "subscription-manager attach --pool=RHEL_POOL" | adddate  >> /var/log/jbosseap.install.log
subscription-manager attach --pool=${RHEL_POOL} >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Pool Attach for RHEL Failed" | adddate >> /var/log/jbosseap.install.log; exit $flag;  fi
#######################

####################### Install openjdk: is it needed? it should be installed with eap7.3
echo "Install openjdk, wget, git, unzip, vim" | adddate >> /var/log/jbosseap.install.log
echo "sudo yum install java-1.8.0-openjdk wget unzip vim git -y" | adddate >> /var/log/jbosseap.install.log
sudo yum install wget unzip vim git -y | adddate >> /var/log/jbosseap.install.log 2>&1 #java-1.8.0-openjdk
####################### 


####################### Install JBoss EAP 7.3
echo "subscription-manager repos --enable=jb-eap-7.3-for-rhel-8-x86_64-rpms" | adddate >> /var/log/jbosseap.install.log
subscription-manager repos --enable=jb-eap-7.3-for-rhel-8-x86_64-rpms >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Enabling repos for JBoss EAP Failed" | adddate >> /var/log/jbosseap.install.log; exit $flag;  fi

echo "Installing JBoss EAP 7.3 repos" | adddate >> /var/log/jbosseap.install.log
echo "yum groupinstall -y jboss-eap7" | adddate >> /var/log/jbosseap.install.log
yum groupinstall -y jboss-eap7 >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP installation Failed" | adddate >> /var/log/jbosseap.install.log; exit $flag;  fi

echo "sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config" | adddate >> /var/log/jbosseap.install.log
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config | adddate >> /var/log/jbosseap.install.log 2>&1
echo "echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config" | adddate >> /var/log/jbosseap.install.log
echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config | adddate >> /var/log/jbosseap.install.log 2>&1
####################### 

echo "systemctl restart sshd" | adddate >> /var/log/jbosseap.install.log
systemctl restart sshd | adddate >> /var/log/jbosseap.install.log 2>&1

echo "Copy the standalone-azure-ha.xml from EAP_HOME/doc/wildfly/examples/configs folder to EAP_HOME/wildfly/standalone/configuration folder" | adddate >> /var/log/jbosseap.install.log
echo "cp $EAP_HOME/doc/wildfly/examples/configs/standalone-azure-ha.xml $EAP_HOME/wildfly/standalone/configuration/" | adddate >> /var/log/jbosseap.install.log
cp $EAP_HOME/doc/wildfly/examples/configs/standalone-azure-ha.xml $EAP_HOME/wildfly/standalone/configuration/ | adddate >> /var/log/jbosseap.install.log 2>&1

echo "change the jgroups stack from UDP to TCP " | adddate >> /var/log/jbosseap.install.log
echo "sed -i 's/stack="udp"/stack="tcp"/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml" | adddate >> /var/log/jbosseap.install.log
sed -i 's/stack="udp"/stack="tcp"/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml | adddate >> /var/log/jbosseap.install.log 2>&1

echo "Update interfaces section update jboss.bind.address.management, jboss.bind.address and jboss.bind.address.private from 127.0.0.1 to 0.0.0.0" | adddate >> /var/log/jbosseap.install.log
echo "sed -i 's/jboss.bind.address.management:127.0.0.1/jboss.bind.address.management:0.0.0.0/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml" | adddate >> /var/log/jbosseap.install.log
sed -i 's/jboss.bind.address.management:127.0.0.1/jboss.bind.address.management:0.0.0.0/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml | adddate >> /var/log/jbosseap.install.log 2>&1
echo "sed -i 's/jboss.bind.address:127.0.0.1/jboss.bind.address:0.0.0.0/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml" | adddate >> /var/log/jbosseap.install.log
sed -i 's/jboss.bind.address:127.0.0.1/jboss.bind.address:0.0.0.0/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml | adddate >> /var/log/jbosseap.install.log 2>&1
echo "sed -i 's/jboss.bind.address.private:127.0.0.1/jboss.bind.address.private:0.0.0.0/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml" | adddate >> /var/log/jbosseap.install.log
sed -i 's/jboss.bind.address.private:127.0.0.1/jboss.bind.address.private:0.0.0.0/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml | adddate >> /var/log/jbosseap.install.log 2>&1

echo "Start JBoss server" | adddate >> /var/log/jbosseap.install.log
echo "$EAP_HOME/wildfly/bin/standalone.sh -bprivate $IP_ADDR -b $IP_ADDR -bmanagement $IP_ADDR --server-config=standalone-azure-ha.xml -Djboss.jgroups.azure_ping.storage_account_name=$STORAGE_ACCOUNT_NAME -Djboss.jgroups.azure_ping.storage_access_key=STORAGE_ACCESS_KEY -Djboss.jgroups.azure_ping.container=$CONTAINER_NAME -Djava.net.preferIPv4Stack=true &" | adddate >> /var/log/jbosseap.install.log
$EAP_HOME/wildfly/bin/standalone.sh -bprivate $IP_ADDR -b $IP_ADDR -bmanagement $IP_ADDR --server-config=standalone-azure-ha.xml -Djboss.jgroups.azure_ping.storage_account_name=$STORAGE_ACCOUNT_NAME -Djboss.jgroups.azure_ping.storage_access_key=$STORAGE_ACCESS_KEY -Djboss.jgroups.azure_ping.container=$CONTAINER_NAME -Djava.net.preferIPv4Stack=true | adddate >> /var/log/jbosseap.install.log 2>&1 &
sleep 20

echo "export EAP_HOME="/opt/rh/eap7/root/usr/share"" >> /bin/jbossservice.sh
echo "$EAP_HOME/wildfly/bin/standalone.sh -bprivate $IP_ADDR -b $IP_ADDR -bmanagement $IP_ADDR --server-config=standalone-azure-ha.xml -Djboss.jgroups.azure_ping.storage_account_name=$STORAGE_ACCOUNT_NAME -Djboss.jgroups.azure_ping.storage_access_key=$STORAGE_ACCESS_KEY -Djboss.jgroups.azure_ping.container=$CONTAINER_NAME -Djava.net.preferIPv4Stack=true &" >> /bin/jbossservice.sh
chmod +x /bin/jbossservice.sh

yum install cronie cronie-anacron | adddate >> /var/log/jbosseap.install.log 2>&1
service crond start | adddate >> /var/log/jbosseap.install.log 2>&1
chkconfig crond on | adddate >> /var/log/jbosseap.install.log 2>&1
echo "@reboot sleep 90 && /bin/jbossservice.sh" >>  /var/spool/cron/root
chmod 600 /var/spool/cron/root

echo "Deploy an application" | adddate >> /var/log/jbosseap.install.log
echo "wget -O eap-session-replication.war $fileUrl" | adddate >> /var/log/jbosseap.install.log
wget -O "eap-session-replication.war" "$fileUrl" >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Sample Application Download Failed" | adddate >> /var/log/jbosseap.install.log; exit $flag; fi
echo "cp ./eap-session-replication.war $EAP_HOME/wildfly/standalone/deployments/" | adddate >> /var/log/jbosseap.install.log
cp ./eap-session-replication.war $EAP_HOME/wildfly/standalone/deployments/ | adddate >> /var/log/jbosseap.install.log 2>&1
echo "touch $EAP_HOME/wildfly/standalone/deployments/eap-session-replication.war.dodeploy" | adddate >> /var/log/jbosseap.install.log
touch $EAP_HOME/wildfly/standalone/deployments/eap-session-replication.war.dodeploy | adddate >> /var/log/jbosseap.install.log 2>&1

echo "Configuring JBoss EAP management user..." | adddate >> /var/log/jbosseap.install.log
echo "$EAP_HOME/wildfly/bin/add-user.sh -u JBOSS_EAP_USER -p JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup'" | adddate >> /var/log/jbosseap.install.log
$EAP_HOME/wildfly/bin/add-user.sh  -u $JBOSS_EAP_USER -p $JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup' >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP management user configuration Failed" | adddate >> /var/log/jbosseap.install.log; exit $flag;  fi

# Seeing a race condition timing error so sleep to delay
sleep 20

echo "Red Hat JBoss EAP Cluster Intallation End " | adddate >> /var/log/jbosseap.install.log
/bin/date +%H:%M:%S  >> /var/log/jbosseap.install.log