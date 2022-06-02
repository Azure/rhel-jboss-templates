#!/bin/bash

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

# Mount the Azure file share on all VMs created
function mountFileShare()
{
  echo "Creating mount point"
  echo "Mount point: $MOUNT_POINT_PATH"
  sudo mkdir -p $MOUNT_POINT_PATH
  if [ ! -d "/etc/smbcredentials" ]; then
    sudo mkdir /etc/smbcredentials
  fi
  if [ ! -f "/etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred" ]; then
    echo "Crearing smbcredentials"
    echo "username=$STORAGE_ACCOUNT_NAME >> /etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred"
    echo "password=$STORAGE_ACCESS_KEY >> /etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred"
    sudo bash -c "echo "username=$STORAGE_ACCOUNT_NAME" >> /etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred"
    sudo bash -c "echo "password=$STORAGE_ACCESS_KEY" >> /etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred"
  fi
  echo "chmod 600 /etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred"
  sudo chmod 600 /etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred
  echo "//${STORAGE_ACCOUNT_PRIVATE_IP}/jbossshare $MOUNT_POINT_PATH cifs nofail,vers=2.1,credentials=/etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred ,dir_mode=0777,file_mode=0777,serverino"
  sudo bash -c "echo \"//${STORAGE_ACCOUNT_PRIVATE_IP}/jbossshare $MOUNT_POINT_PATH cifs nofail,vers=2.1,credentials=/etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred ,dir_mode=0777,file_mode=0777,serverino\" >> /etc/fstab"
  echo "mount -t cifs //${STORAGE_ACCOUNT_PRIVATE_IP}/jbossshare $MOUNT_POINT_PATH -o vers=2.1,credentials=/etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0777,serverino"
  sudo mount -t cifs //${STORAGE_ACCOUNT_PRIVATE_IP}/jbossshare $MOUNT_POINT_PATH -o vers=2.1,credentials=/etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0777,serverino
  if [[ $? != 0 ]];
  then
         echo "Failed to mount //${STORAGE_ACCOUNT_PRIVATE_IP}/jbossshare $MOUNT_POINT_PATH"
	 exit 1
  fi
}

# Get domain.xml file from share point to slave host vm
function getDomainXmlFileFromShare()
{
  sudo -u jboss mv $EAP_HOME/wildfly/domain/configuration/domain.xml $EAP_HOME/wildfly/domain/configuration/domain.xml.backup
  sudo -u jboss cp ${MOUNT_POINT_PATH}/domain.xml $EAP_HOME/wildfly/domain/configuration/.
  ls -lt $EAP_HOME/wildfly/domain/configuration/domain.xml
  if [[ $? != 0 ]]; 
  then
      echo "Failed to get ${MOUNT_POINT_PATH}/domain.xml"
      exit 1
  fi
  sudo -u jboss chmod 640 $EAP_HOME/wildfly/domain/configuration/domain.xml
}

echo "Red Hat JBoss EAP Cluster Intallation Start " | log; flag=${PIPESTATUS[0]}
/bin/date +%H:%M:%S | log; flag=${PIPESTATUS[0]}

export EAP_LAUNCH_CONFIG="/opt/rh/eap7/root/usr/share/wildfly/bin/domain.conf"
echo 'export EAP_RPM_CONF_DOMAIN="/etc/opt/rh/eap7/wildfly/eap7-domain.conf"' >> ~/.bash_profile
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

JBOSS_EAP_USER=$9
JBOSS_EAP_PASSWORD_BASE64=${10}
JBOSS_EAP_PASSWORD=$(echo $JBOSS_EAP_PASSWORD_BASE64 | base64 -d)
RHSM_USER=${11}
RHSM_PASSWORD_BASE64=${12}
RHSM_PASSWORD=$(echo $RHSM_PASSWORD_BASE64 | base64 -d)
EAP_POOL=${13}
STORAGE_ACCOUNT_NAME=${14}
CONTAINER_NAME=${15}
STORAGE_ACCESS_KEY=${16}
STORAGE_ACCOUNT_PRIVATE_IP=${17}
DOMAIN_CONTROLLER_PRIVATE_IP=${18}
NUMBER_OF_SERVER_INSTANCE=${19}
HOST_VM_NAME=$(hostname)
HOST_VM_NAME_LOWERCASES=$(echo "${HOST_VM_NAME,,}")
HOST_VM_IP=$(hostname -I)

MOUNT_POINT_PATH=/mnt/jbossshare
SCRIPT_PWD=`pwd`

echo "JBoss EAP admin user: " ${JBOSS_EAP_USER} | log; flag=${PIPESTATUS[0]}
echo "JBoss EAP on RHEL version you selected : JBoss-EAP7.3-on-RHEL8.4" | log; flag=${PIPESTATUS[0]}
echo "Storage Account Name: " ${STORAGE_ACCOUNT_NAME} | log; flag=${PIPESTATUS[0]}
echo "Storage Container Name: " ${CONTAINER_NAME} | log; flag=${PIPESTATUS[0]}
echo "RHSM_USER: " ${RHSM_USER} | log; flag=${PIPESTATUS[0]}

echo "Folder where script is executing ${pwd}" | log; flag=${PIPESTATUS[0]}

####################### Configuring firewall for ports
echo "Configure firewall for ports 8080, 9990, 45700, 7600" | log; flag=${PIPESTATUS[0]}

openport 9999
openport 8443
openport 8009
openport 9990
openport 45700
openport 7600

echo "iptables-save" | log; flag=${PIPESTATUS[0]}
sudo iptables-save   | log; flag=${PIPESTATUS[0]}
####################### 

echo "Initial JBoss EAP setup" | log; flag=${PIPESTATUS[0]}
####################### Register to subscription Manager
echo "Register subscription manager" | log; flag=${PIPESTATUS[0]}
echo "subscription-manager register --username RHSM_USER --password RHSM_PASSWORD" | log; flag=${PIPESTATUS[0]}
subscription-manager register --username $RHSM_USER --password $RHSM_PASSWORD --force | log; flag=${PIPESTATUS[0]}
if [ $flag != 0 ] ; then echo  "ERROR! Red Hat Manager Registration Failed" >&2 log; exit $flag;  fi
#######################

sleep 20

####################### Attach EAP Pool
echo "Subscribing the system to get access to JBoss EAP repos" | log; flag=${PIPESTATUS[0]}
echo "subscription-manager attach --pool=EAP_POOL" | log; flag=${PIPESTATUS[0]}
subscription-manager attach --pool=${EAP_POOL} | log; flag=${PIPESTATUS[0]}
if [ $flag != 0 ] ; then echo  "ERROR! Pool Attach for JBoss EAP Failed" >&2 log; exit $flag;  fi
#######################

####################### Install openjdk: is it needed? it should be installed with eap7.3
echo "Install openjdk, curl, wget, git, unzip, vim" | log; flag=${PIPESTATUS[0]}
echo "sudo yum install java-1.8.4-openjdk curl wget unzip vim git -y" | log; flag=${PIPESTATUS[0]}
sudo yum install curl wget unzip vim git -y | log; flag=${PIPESTATUS[0]}#java-1.8.4-openjdk
####################### 

####################### Install JBoss EAP 7.3
echo "subscription-manager repos --enable=jb-eap-7.3-for-rhel-8-x86_64-rpms" | log; flag=${PIPESTATUS[0]}
subscription-manager repos --enable=jb-eap-7.3-for-rhel-8-x86_64-rpms | log; flag=${PIPESTATUS[0]}
if [ $flag != 0 ] ; then echo  "ERROR! Enabling repos for JBoss EAP Failed" >&2 log; exit $flag;  fi

echo "Installing JBoss EAP 7.3 repos" | log; flag=${PIPESTATUS[0]}
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

echo "Updating domain.xml" | log; flag=${PIPESTATUS[0]}
yum install update -y
yum install cifs-utils -y
mountFileShare
getDomainXmlFileFromShare

JBOSS_EAP_PASSWORD_ENCODE=$(echo $JBOSS_EAP_PASSWORD | base64)


sudo touch ${EAP_HOME}/wildfly/domain/configuration/addservercmd.txt
sudo chmod 666 ${EAP_HOME}/wildfly/domain/configuration/addservercmd.txt
for ((i = 0; i < NUMBER_OF_SERVER_INSTANCE; i++)); do
	port_offset=$(( i*150 ))
    port=$(( port_offset + 8080 ))
    echo "open port: $port"
    openport $port
    sudo -u jboss echo "/host=${HOST_VM_NAME_LOWERCASES}/server-config=${HOST_VM_NAME_LOWERCASES}-server${i}:add(group=main-server-group, socket-binding-port-offset=${port_offset})" >> ${EAP_HOME}/wildfly/domain/configuration/addservercmd.txt
done

echo "firewall-cmd --reload" | log; flag=${PIPESTATUS[0]}
sudo firewall-cmd  --reload  | log; flag=${PIPESTATUS[0]}

# sudo -u jboss $EAP_HOME/wildfly/bin/jboss-cli.sh --echo-command \
sudo -u jboss $EAP_HOME/wildfly/bin/jboss-cli.sh --echo-command \
"embed-host-controller --std-out=echo --domain-config=domain.xml --host-config=host-slave.xml",\
"/host=${HOST_VM_NAME_LOWERCASES}/core-service=management/security-realm=ManagementRealm/server-identity=secret:write-attribute(name=\"value\", value=\"${JBOSS_EAP_PASSWORD_ENCODE}\")",\
"/host=${HOST_VM_NAME_LOWERCASES}/server-config=server-one:remove",\
"/host=${HOST_VM_NAME_LOWERCASES}/server-config=server-two:remove",\
"run-batch --file=${EAP_HOME}/wildfly/domain/configuration/addservercmd.txt",\
"/host=${HOST_VM_NAME_LOWERCASES}/core-service=discovery-options/static-discovery=primary:write-attribute(name=host, value=${DOMAIN_CONTROLLER_PRIVATE_IP})",\
"/host=${HOST_VM_NAME_LOWERCASES}:write-attribute(name=domain-controller.remote.username, value=${JBOSS_EAP_USER})",\
"/host=${HOST_VM_NAME_LOWERCASES}/interface=unsecured:add(inet-address=${HOST_VM_IP})",\
"/host=${HOST_VM_NAME_LOWERCASES}/interface=management:write-attribute(name=inet-address, value=${HOST_VM_IP})",\
"/host=${HOST_VM_NAME_LOWERCASES}/interface=public:write-attribute(name=inet-address, value=${HOST_VM_IP})" | log; flag=${PIPESTATUS[0]}

####################### Configure the JBoss server and setup eap service
echo "Setting configurations in $EAP_RPM_CONF_DOMAIN"
echo -e "\t-> WILDFLY_HOST_CONFIG=host-slave.xml" | log; flag=${PIPESTATUS[0]}
echo 'WILDFLY_HOST_CONFIG=host-slave.xml' >> $EAP_RPM_CONF_DOMAIN | log; flag=${PIPESTATUS[0]}

####################### Start the JBoss server and setup eap service
echo "Start JBoss-EAP service"                  | log; flag=${PIPESTATUS[0]}
echo "systemctl enable eap7-domain.service" | log; flag=${PIPESTATUS[0]}
systemctl enable eap7-domain.service        | log; flag=${PIPESTATUS[0]}
####################### 

###################### Editing eap7-domain.services
echo "Adding - After=syslog.target network.target NetworkManager-wait-online.service" | log; flag=${PIPESTATUS[0]}
sed -i 's/After=syslog.target network.target/After=syslog.target network.target NetworkManager-wait-online.service/' /usr/lib/systemd/system/eap7-domain.service | log; flag=${PIPESTATUS[0]}
echo "Adding - Wants=NetworkManager-wait-online.service \nBefore=httpd.service" | log; flag=${PIPESTATUS[0]}
sed -i 's/Before=httpd.service/Wants=NetworkManager-wait-online.service \nBefore=httpd.service/' /usr/lib/systemd/system/eap7-domain.service | log; flag=${PIPESTATUS[0]}
echo "Removing - User=jboss Group=jboss" | log; flag=${PIPESTATUS[0]}
# sed -i '/User/d' /usr/lib/systemd/system/eap7-domain.service | log; flag=${PIPESTATUS[0]}
# sed -i '/Group/d' /usr/lib/systemd/system/eap7-domain.service | log; flag=${PIPESTATUS[0]}
echo "systemctl daemon-reload" | log; flag=${PIPESTATUS[0]}
systemctl daemon-reload | log; flag=${PIPESTATUS[0]}

echo "systemctl restart eap7-domain.service"| log; flag=${PIPESTATUS[0]}
systemctl restart eap7-domain.service       | log; flag=${PIPESTATUS[0]}
echo "systemctl status eap7-domain.service" | log; flag=${PIPESTATUS[0]}
systemctl status eap7-domain.service        | log; flag=${PIPESTATUS[0]}
######################

echo "Configuring JBoss EAP management user..." | log; flag=${PIPESTATUS[0]}
echo "$EAP_HOME/wildfly/bin/add-user.sh -u JBOSS_EAP_USER -p JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup'" | log; flag=${PIPESTATUS[0]}
$EAP_HOME/wildfly/bin/add-user.sh  -u $JBOSS_EAP_USER -p $JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup' | log; flag=${PIPESTATUS[0]}
if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP management user configuration Failed" >&2 log; exit $flag;  fi

# Seeing a race condition timing error so sleep to delay
sleep 20

echo "Red Hat JBoss EAP Cluster Intallation End " | log; flag=${PIPESTATUS[0]}
/bin/date +%H:%M:%S | log
