#!/bin/sh

log() {
    while IFS= read -r line; do
        printf '%s %s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$line" >> /var/log/jbosseap.install.log
    done
}

# firewalld installation and configuration
if ! rpm -qa | grep firewalld 2>&1 > /dev/null ; then
    sudo yum update -y --disablerepo='*' --enablerepo='*microsoft*' | log; flag=${PIPESTATUS[0]}
    sudo yum install firewalld -y | log; flag=${PIPESTATUS[0]}
    sudo systemctl start firewalld
    sudo systemctl enable firewalld
fi
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

JBOSS_EAP_USER=${1}
JBOSS_EAP_PASSWORD_BASE64=${2}
JBOSS_EAP_PASSWORD=$(echo $JBOSS_EAP_PASSWORD_BASE64 | base64 -d)
JDK_VERSION=${3}
STORAGE_ACCOUNT_NAME=${4}
CONTAINER_NAME=${5}
STORAGE_ACCESS_KEY=${6}
STORAGE_ACCOUNT_PRIVATE_IP=${7}
DOMAIN_CONTROLLER_PRIVATE_IP=${8}
NUMBER_OF_SERVER_INSTANCE=${9}
CONNECT_SATELLITE=${10}
SATELLITE_ACTIVATION_KEY_BASE64=${11}
SATELLITE_ACTIVATION_KEY=$(echo $SATELLITE_ACTIVATION_KEY_BASE64 | base64 -d)
SATELLITE_ORG_NAME_BASE64=${12}
SATELLITE_ORG_NAME=$(echo $SATELLITE_ORG_NAME_BASE64 | base64 -d)
SATELLITE_VM_FQDN=${13}
enableDB=${14}
dbType=${15}
jdbcDSJNDIName=${16}
dsConnectionString=${17}
databaseUser=${18}
databasePassword=${19}

HOST_VM_NAME=$(hostname)
HOST_VM_NAME_LOWERCASES=$(echo "${HOST_VM_NAME,,}")
HOST_VM_IP=$(hostname -I)

MOUNT_POINT_PATH=/mnt/jbossshare
SCRIPT_PWD=`pwd`
CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(readlink -f ${CURR_DIR})"

echo "JBoss EAP admin user: " ${JBOSS_EAP_USER} | log; flag=${PIPESTATUS[0]}
echo "JBoss EAP on RHEL version you selected : JBoss-EAP7.4-on-RHEL8.4" | log; flag=${PIPESTATUS[0]}
echo "Storage Account Name: " ${STORAGE_ACCOUNT_NAME} | log; flag=${PIPESTATUS[0]}
echo "Storage Container Name: " ${CONTAINER_NAME} | log; flag=${PIPESTATUS[0]}

echo "Folder where script is executing ${pwd}" | log; flag=${PIPESTATUS[0]}

####################### Configuring firewall for ports
echo "Configure firewall for ports 8080, 9990, 45700, 7600" | log; flag=${PIPESTATUS[0]}

openport 9999
openport 8443
openport 8009
openport 9990
openport 9993
openport 45700
openport 7600

echo "iptables-save" | log; flag=${PIPESTATUS[0]}
sudo iptables-save   | log; flag=${PIPESTATUS[0]}
####################### 

echo "Initial JBoss EAP setup" | log; flag=${PIPESTATUS[0]}

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

fi

####################### Install openjdk: is it needed? it should be installed with eap7.4
echo "Install openjdk, curl, wget, git, unzip, vim" | log; flag=${PIPESTATUS[0]}
echo "sudo yum install curl wget unzip vim git -y" | log; flag=${PIPESTATUS[0]}
sudo yum install curl wget unzip vim git -y | log; flag=${PIPESTATUS[0]}#java-1.8.4-openjdk
####################### 

## OpenJDK 17 specific logic
if [[ "${JDK_VERSION,,}" == "openjdk17" ]]; then
    cp ${BASE_DIR}/enable-elytron-se17-domain.cli $EAP_HOME/wildfly/docs/examples/enable-elytron-se17-domain.cli
    chmod 644 $EAP_HOME/wildfly/docs/examples/enable-elytron-se17-domain.cli
    sudo -u jboss $EAP_HOME/wildfly/bin/jboss-cli.sh --file=$EAP_HOME/wildfly/docs/examples/enable-elytron-se17-domain.cli
fi

echo "Updating domain.xml" | log; flag=${PIPESTATUS[0]}
yum install update -y
yum install cifs-utils -y
mountFileShare
getDomainXmlFileFromShare

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
"/host=${HOST_VM_NAME_LOWERCASES}/server-config=server-one:remove",\
"/host=${HOST_VM_NAME_LOWERCASES}/server-config=server-two:remove",\
"/host=${HOST_VM_NAME_LOWERCASES}/core-service=discovery-options/static-discovery=primary:remove",\
"run-batch --file=${EAP_HOME}/wildfly/domain/configuration/addservercmd.txt",\
"/host=${HOST_VM_NAME_LOWERCASES}/subsystem=elytron/authentication-configuration=slave:add(authentication-name=${JBOSS_EAP_USER}, credential-reference={clear-text=${JBOSS_EAP_PASSWORD}})",\
"/host=${HOST_VM_NAME_LOWERCASES}/subsystem=elytron/authentication-context=slave-context:add(match-rules=[{authentication-configuration=slave}])",\
"/host=${HOST_VM_NAME_LOWERCASES}:write-attribute(name=domain-controller.remote, value={host=${DOMAIN_CONTROLLER_PRIVATE_IP}, port=9990, protocol=remote+http, authentication-context=slave-context})",\
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

# Install JDBC driver module and test data source connection
if [ "$enableDB" == "True" ]; then
    echo "Start to install JDBC driver module" | log
    jdbcDataSourceName=dataSource-$dbType
    ./create-ds-${dbType}.sh $EAP_HOME/wildfly "$jdbcDataSourceName" "$jdbcDSJNDIName" "$dsConnectionString" "$databaseUser" "$databasePassword" true true
    echo "Complete to install JDBC driver module" | log
fi

echo "Red Hat JBoss EAP Cluster Intallation End " | log; flag=${PIPESTATUS[0]}
/bin/date +%H:%M:%S | log
