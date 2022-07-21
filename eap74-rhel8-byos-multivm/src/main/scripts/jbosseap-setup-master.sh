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

# Copy domain.xml file from master host vm to share point
function copyDomainXmlFileToShare()
{
  sudo -u jboss cp $EAP_HOME/wildfly/domain/configuration/domain.xml ${MOUNT_POINT_PATH}/.
  ls -lt ${MOUNT_POINT_PATH}/domain.xml
  if [[ $? != 0 ]]; 
  then
      echo "Failed to copy $EAP_HOME/wildfly/domain/configuration/domain.xml"
      exit 1
  fi
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
RHEL_POOL=${14}
STORAGE_ACCOUNT_NAME=${15}
CONTAINER_NAME=${16}
STORAGE_ACCESS_KEY=${17}
STORAGE_ACCOUNT_PRIVATE_IP=${18}
CONNECT_SATELLITE=${19}
SATELLITE_ACTIVATION_KEY_BASE64=${20}
SATELLITE_ACTIVATION_KEY=$(echo $SATELLITE_ACTIVATION_KEY_BASE64 | base64 -d)
SATELLITE_ORG_NAME_BASE64=${21}
SATELLITE_ORG_NAME=$(echo $SATELLITE_ORG_NAME_BASE64 | base64 -d)
SATELLITE_VM_FQDN=${22}

MOUNT_POINT_PATH=/mnt/jbossshare
HOST_VM_IP=$(hostname -I)

echo "JBoss EAP admin user: " ${JBOSS_EAP_USER} | log; flag=${PIPESTATUS[0]}
echo "JBoss EAP on RHEL version you selected : JBoss-EAP7.4-on-RHEL8.4" | log; flag=${PIPESTATUS[0]}
echo "Storage Account Name: " ${STORAGE_ACCOUNT_NAME} | log; flag=${PIPESTATUS[0]}
echo "Storage Container Name: " ${CONTAINER_NAME} | log; flag=${PIPESTATUS[0]}
echo "RHSM_USER: " ${RHSM_USER} | log; flag=${PIPESTATUS[0]}

echo "Folder where script is executing ${pwd}" | log; flag=${PIPESTATUS[0]}

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
sudo firewall-cmd  --reload  | log; flag=${PIPESTATUS[0]}

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
else
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
fi

####################### Attach RHEL Pool
echo "Attaching Pool ID for RHEL OS" | log; flag=${PIPESTATUS[0]}
if [ "$EAP_POOL" != "$RHEL_POOL" ]; then
    echo "subscription-manager attach --pool=RHEL_POOL" | log; flag=${PIPESTATUS[0]}
    subscription-manager attach --pool=${RHEL_POOL}  | log; flag=${PIPESTATUS[0]}
    if [ $flag != 0 ] ; then echo  "ERROR! Pool Attach for RHEL Failed" >&2 log; exit $flag;  fi
else
    echo "Using the same pool to get access to RHEL repos" | log; flag=${PIPESTATUS[0]}
fi
#######################

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

echo "Updating domain.xml" | log; flag=${PIPESTATUS[0]}
echo -e "\t stack UDP to TCP"           | log; flag=${PIPESTATUS[0]}
echo -e "\t re-write stack TCP"        | log; flag=${PIPESTATUS[0]}
echo -e "\t change main-server-group profile to ha"        | log; flag=${PIPESTATUS[0]}
echo -e "\t change main-server-group socket-binding-group to ha-sockets"        | log; flag=${PIPESTATUS[0]}
echo -e "\t unsecure:inet-address"        | log; flag=${PIPESTATUS[0]}
echo -e "\t management:inet-address"    | log; flag=${PIPESTATUS[0]}
echo -e "\t public:inet-address"        | log; flag=${PIPESTATUS[0]}
echo -e "\t set transaction id"         | log; flag=${PIPESTATUS[0]}

# sudo -u jboss $EAP_HOME/wildfly/bin/jboss-cli.sh --echo-command \
sudo -u jboss $EAP_HOME/wildfly/bin/jboss-cli.sh --echo-command \
'embed-host-controller --std-out=echo --domain-config=domain.xml --host-config=host-master.xml',\
':write-attribute(name=name,value=domain1)',\
'/profile=ha/subsystem=jgroups/stack=tcp:remove',\
'/profile=ha/subsystem=jgroups/stack=tcp:add()',\
'/profile=ha/subsystem=jgroups/stack=tcp/transport=TCP:add(socket-binding=jgroups-tcp,properties={ip_mcast=false})',\
"/profile=ha/subsystem=jgroups/stack=tcp/protocol=azure.AZURE_PING:add(properties={storage_account_name=\"${STORAGE_ACCOUNT_NAME}\", storage_access_key=\"${STORAGE_ACCESS_KEY}\", container=\"${CONTAINER_NAME}\"})",\
'/profile=ha/subsystem=jgroups/stack=tcp/protocol=MERGE3:add',\
'/profile=ha/subsystem=jgroups/stack=tcp/protocol=FD_SOCK:add(socket-binding=jgroups-tcp-fd)',\
'/profile=ha/subsystem=jgroups/stack=tcp/protocol=FD_ALL:add',\
'/profile=ha/subsystem=jgroups/stack=tcp/protocol=VERIFY_SUSPECT:add',\
'/profile=ha/subsystem=jgroups/stack=tcp/protocol=pbcast.NAKACK2:add(properties={use_mcast_xmit=false,use_mcast_xmit_req=false})',\
'/profile=ha/subsystem=jgroups/stack=tcp/protocol=UNICAST3:add',\
'/profile=ha/subsystem=jgroups/stack=tcp/protocol=pbcast.STABLE:add',\
'/profile=ha/subsystem=jgroups/stack=tcp/protocol=pbcast.GMS:add',\
'/profile=ha/subsystem=jgroups/stack=tcp/protocol=MFC:add',\
'/profile=ha/subsystem=jgroups/stack=tcp/protocol=FRAG3:add',\
'/profile=ha/subsystem=jgroups/channel=ee:write-attribute(name="stack", value="tcp")',\
'/server-group=main-server-group:write-attribute(name="profile", value="ha")',\
'/server-group=main-server-group:write-attribute(name="socket-binding-group", value="ha-sockets")',\
"/host=master/interface=unsecure:add(inet-address=${HOST_VM_IP})",\
"/host=master/interface=management:write-attribute(name=inet-address, value=${HOST_VM_IP})",\
"/host=master/interface=public:add(inet-address=${HOST_VM_IP})" | log; flag=${PIPESTATUS[0]}

####################### Save domain.xml to file share services for slave hosts.
yum install update -y
yum install cifs-utils -y
mountFileShare
copyDomainXmlFileToShare

####################### Configure the JBoss server and setup eap service
echo "Setting configurations in $EAP_RPM_CONF_DOMAIN"
echo -e "\t-> WILDFLY_HOST_CONFIG=host-master.xml" | log; flag=${PIPESTATUS[0]}
echo 'WILDFLY_HOST_CONFIG=host-master.xml' >> $EAP_RPM_CONF_DOMAIN | log; flag=${PIPESTATUS[0]}

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

echo "Red Hat JBoss EAP Cluster Intallation End " | log; flag=${PIPESTATUS[0]}
/bin/date +%H:%M:%S | log
