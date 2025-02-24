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

# Mount the Azure file share on all VMs created
function mountFileShare()
{
  echo "Creating mount point" | log; flag=${PIPESTATUS[0]}
  echo "Mount point: $MOUNT_POINT_PATH" | log; flag=${PIPESTATUS[0]}
  sudo mkdir -p $MOUNT_POINT_PATH | log; flag=${PIPESTATUS[0]}
  if [ ! -d "/etc/smbcredentials" ]; then
    sudo mkdir /etc/smbcredentials | log; flag=${PIPESTATUS[0]}
  fi
  if [ ! -f "/etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred" ]; then
    echo "Crearing smbcredentials" | log; flag=${PIPESTATUS[0]}
    echo "username=$STORAGE_ACCOUNT_NAME >> /etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred" | log; flag=${PIPESTATUS[0]}
    echo "password=$STORAGE_ACCESS_KEY >> /etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred" | log; flag=${PIPESTATUS[0]}
    sudo bash -c "echo "username=$STORAGE_ACCOUNT_NAME" >> /etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred" | log; flag=${PIPESTATUS[0]}
    sudo bash -c "echo "password=$STORAGE_ACCESS_KEY" >> /etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred" | log; flag=${PIPESTATUS[0]}
  fi
  echo "chmod 600 /etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred" | log; flag=${PIPESTATUS[0]}
  sudo chmod 600 /etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred | log; flag=${PIPESTATUS[0]}
  echo "//${STORAGE_ACCOUNT_PRIVATE_IP}/jbossshare $MOUNT_POINT_PATH cifs nofail,vers=2.1,credentials=/etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred ,dir_mode=0777,file_mode=0777,serverino" | log; flag=${PIPESTATUS[0]}
  sudo bash -c "echo \"//${STORAGE_ACCOUNT_PRIVATE_IP}/jbossshare $MOUNT_POINT_PATH cifs nofail,vers=2.1,credentials=/etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred ,dir_mode=0777,file_mode=0777,serverino\" >> /etc/fstab" | log; flag=${PIPESTATUS[0]}
  echo "mount -t cifs //${STORAGE_ACCOUNT_PRIVATE_IP}/jbossshare $MOUNT_POINT_PATH -o vers=2.1,credentials=/etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0777,serverino" | log; flag=${PIPESTATUS[0]}
  sudo mount -t cifs //${STORAGE_ACCOUNT_PRIVATE_IP}/jbossshare $MOUNT_POINT_PATH -o vers=2.1,credentials=/etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0777,serverino | log; flag=${PIPESTATUS[0]}
  if [ $flag != 0 ] ; then echo "Failed to mount //${STORAGE_ACCOUNT_PRIVATE_IP}/jbossshare $MOUNT_POINT_PATH" >&2 log; exit $flag;  fi
}

# Copy domain.xml file from master/primary host vm to share point
function copyDomainXmlFileToShare()
{
  sudo -u jboss cp $EAP_HOME/domain/configuration/domain.xml ${MOUNT_POINT_PATH}/.
  ls -lt ${MOUNT_POINT_PATH}/domain.xml | log; flag=${PIPESTATUS[0]}
  if [ $flag != 0 ] ; then echo "Failed to copy $EAP_HOME/domain/configuration/domain.xml" >&2 log; exit $flag;  fi
}

echo "Red Hat JBoss EAP Cluster Intallation Start " | log; flag=${PIPESTATUS[0]}
/bin/date +%H:%M:%S | log; flag=${PIPESTATUS[0]}

JBOSS_EAP_USER=${1}
JBOSS_EAP_PASSWORD_BASE64=${2}
JBOSS_EAP_PASSWORD=$(echo $JBOSS_EAP_PASSWORD_BASE64 | base64 -d)
RHSM_USER=${3}
RHSM_PASSWORD_BASE64=${4}
RHSM_PASSWORD=$(echo $RHSM_PASSWORD_BASE64 | base64 -d)
EAP_POOL=${5}
RHEL_POOL=${6}
JDK_VERSION=${7}
STORAGE_ACCOUNT_NAME=${8}
CONTAINER_NAME=${9}
STORAGE_ACCESS_KEY=${10}
STORAGE_ACCOUNT_PRIVATE_IP=${11}
CONNECT_SATELLITE=${12}
SATELLITE_ACTIVATION_KEY_BASE64=${13}
SATELLITE_ACTIVATION_KEY=$(echo $SATELLITE_ACTIVATION_KEY_BASE64 | base64 -d)
SATELLITE_ORG_NAME_BASE64=${14}
SATELLITE_ORG_NAME=$(echo $SATELLITE_ORG_NAME_BASE64 | base64 -d)
SATELLITE_VM_FQDN=${15}
gracefulShutdownTimeout=${16}

MOUNT_POINT_PATH=/mnt/jbossshare
HOST_VM_IP=$(hostname -I)
CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(readlink -f ${CURR_DIR})"

echo "JBoss EAP admin user: " ${JBOSS_EAP_USER} | log; flag=${PIPESTATUS[0]}
echo "Storage Account Name: " ${STORAGE_ACCOUNT_NAME} | log; flag=${PIPESTATUS[0]}
echo "Storage Container Name: " ${CONTAINER_NAME} | log; flag=${PIPESTATUS[0]}
echo "RHSM_USER: " ${RHSM_USER} | log; flag=${PIPESTATUS[0]}

echo "Folder where script is executing ${pwd}" | log; flag=${PIPESTATUS[0]}

##################### Configure EAP_LAUNCH_CONFIG and EAP_HOME
if [[ "${JDK_VERSION,,}" == "eap8-openjdk17" || "${JDK_VERSION,,}" == "eap8-openjdk11" ]]; then
    export EAP_LAUNCH_CONFIG="/opt/rh/eap8/root/usr/share/wildfly/bin/domain.conf"
    echo 'export EAP_RPM_CONF_DOMAIN="/etc/opt/rh/eap8/wildfly/eap8-domain.conf"' >> ~/.bash_profile
    echo 'export EAP_HOME="/opt/rh/eap8/root/usr/share/wildfly"' >> ~/.bash_profile
    source ~/.bash_profile
    touch /etc/profile.d/eap_env.sh
    echo 'export EAP_HOME="/opt/rh/eap8/root/usr/share/wildfly"' >> /etc/profile.d/eap_env.sh
else
    export EAP_LAUNCH_CONFIG="/opt/rh/eap7/root/usr/share/wildfly/bin/domain.conf"
    echo 'export EAP_RPM_CONF_DOMAIN="/etc/opt/rh/eap7/wildfly/eap7-domain.conf"' >> ~/.bash_profile
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
    if [ $flag != 0 ] ; then echo  "Failed to register host to Satellite server" >&2 log; exit $flag;  fi
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
fi

####################### Install curl, wget, git, unzip, vim
echo "Install curl, wget, git, unzip, vim" | log; flag=${PIPESTATUS[0]}
echo "sudo yum install curl wget unzip vim git -y" | log; flag=${PIPESTATUS[0]}
sudo yum install curl wget unzip vim git -y | log; flag=${PIPESTATUS[0]}#java-1.8.4-openjdk
####################### 

####################### Setitng up the satelitte channels for EAP instalation
if [[ "${JDK_VERSION,,}" == "eap8-openjdk17"  ||  "${JDK_VERSION,,}" == "eap8-openjdk11" ]]; then
# Install JBoss EAP 8
    echo "subscription-manager repos --enable=jb-eap-8.0-for-rhel-9-x86_64-rpms"         | log; flag=${PIPESTATUS[0]}
    subscription-manager repos --enable=jb-eap-8.0-for-rhel-9-x86_64-rpms                | log; flag=${PIPESTATUS[0]}
    if [ $flag != 0 ] ; then echo  "ERROR! Enabling repos for JBoss EAP Failed" >&2 log; exit $flag;  fi
    if [[ "${JDK_VERSION,,}" == "eap8-openjdk17" ]]; then
        echo "Installing JBoss EAP 8 JDK 17" | log; flag=${PIPESTATUS[0]}
        echo "yum groupinstall -y jboss-eap8" | log; flag=${PIPESTATUS[0]}
        yum groupinstall -y jboss-eap8       | log; flag=${PIPESTATUS[0]}
        if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP installation Failed" >&2 log; exit $flag;  fi
    
    elif [[ "${JDK_VERSION,,}" == "eap8-openjdk11" ]]; then
        echo "Installing JBoss EAP 8 JDK 11" | log; flag=${PIPESTATUS[0]}
        echo "yum groupinstall -y jboss-eap8-jdk11" | log; flag=${PIPESTATUS[0]}
        yum groupinstall -y jboss-eap8-jdk11       | log; flag=${PIPESTATUS[0]}
        if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP installation Failed" >&2 log; exit $flag;  fi
    fi
else
# Install JBoss EAP 7.4
    echo "subscription-manager repos --enable=jb-eap-7.4-for-rhel-8-x86_64-rpms"         | log; flag=${PIPESTATUS[0]}
    subscription-manager repos --enable=jb-eap-7.4-for-rhel-8-x86_64-rpms                | log; flag=${PIPESTATUS[0]}
    if [ $flag != 0 ] ; then echo  "ERROR! Enabling repos for JBoss EAP Failed" >&2 log; exit $flag;  fi
    if [[ "${JDK_VERSION,,}" == "eap74-openjdk17" ]]; then
        echo "Installing JBoss EAP 7.4 JDK 17" | log; flag=${PIPESTATUS[0]}
        echo "yum groupinstall -y jboss-eap7-jdk17" | log; flag=${PIPESTATUS[0]}
        yum groupinstall -y jboss-eap7-jdk17       | log; flag=${PIPESTATUS[0]}
        if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP installation Failed" >&2 log; exit $flag;  fi
    
    elif [[ "${JDK_VERSION,,}" == "eap74-openjdk11" ]]; then
        echo "Installing JBoss EAP 7.4 JDK 11" | log; flag=${PIPESTATUS[0]}
        echo "yum groupinstall -y jboss-eap7-jdk11" | log; flag=${PIPESTATUS[0]}
        yum groupinstall -y jboss-eap7-jdk11       | log; flag=${PIPESTATUS[0]}
        if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP installation Failed" >&2 log; exit $flag;  fi
    
     elif [[ "${JDK_VERSION,,}" == "eap74-openjdk8" ]]; then
        echo "Installing JBoss EAP 7.4 JDK 8" | log; flag=${PIPESTATUS[0]}
        echo "yum groupinstall -y jboss-eap7" | log; flag=${PIPESTATUS[0]}
        yum groupinstall -y jboss-eap7       | log; flag=${PIPESTATUS[0]}
        if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP installation Failed" >&2 log; exit $flag;  fi
    fi

fi

echo "sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config" | log; flag=${PIPESTATUS[0]}
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config | log; flag=${PIPESTATUS[0]}
echo "echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config" | log; flag=${PIPESTATUS[0]}
echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config | log; flag=${PIPESTATUS[0]}
####################### 

echo "systemctl restart sshd" | log; flag=${PIPESTATUS[0]}
systemctl restart sshd | log; flag=${PIPESTATUS[0]}

## OpenJDK 17 specific logic
if [[ "${JDK_VERSION,,}" == "eap74-openjdk17" || "${JDK_VERSION,,}" == "eap8-openjdk17" ]]; then
    cp ${BASE_DIR}/enable-elytron-se17-domain.cli $EAP_HOME/docs/examples/enable-elytron-se17-domain.cli
    chmod 644 $EAP_HOME/docs/examples/enable-elytron-se17-domain.cli
    if [[ "${JDK_VERSION,,}" == "eap74-openjdk17" ]]; then
        sudo -u jboss $EAP_HOME/bin/jboss-cli.sh --file=$EAP_HOME/docs/examples/enable-elytron-se17-domain.cli -Dhost_config_primary=host-master.xml -Dhost_config_secondary=host-slave.xml
    else
        sudo -u jboss $EAP_HOME/bin/jboss-cli.sh --file=$EAP_HOME/docs/examples/enable-elytron-se17-domain.cli -Dhost_config_primary=host-primary.xml -Dhost_config_secondary=host-secondary.xml
    fi
fi

echo "Updating domain.xml" | log; flag=${PIPESTATUS[0]}
echo -e "\t stack UDP to TCP"           | log; flag=${PIPESTATUS[0]}
echo -e "\t re-write stack TCP"        | log; flag=${PIPESTATUS[0]}
echo -e "\t change main-server-group profile to ha"        | log; flag=${PIPESTATUS[0]}
echo -e "\t change main-server-group socket-binding-group to ha-sockets"        | log; flag=${PIPESTATUS[0]}
echo -e "\t unsecure:inet-address"        | log; flag=${PIPESTATUS[0]}
echo -e "\t management:inet-address"    | log; flag=${PIPESTATUS[0]}
echo -e "\t public:inet-address"        | log; flag=${PIPESTATUS[0]}
echo -e "\t set transaction id"         | log; flag=${PIPESTATUS[0]}

if [[ "${JDK_VERSION,,}" == "eap8-openjdk17" || "${JDK_VERSION,,}" == "eap8-openjdk11" ]]; then
    echo "EAP_HOME is" $EAP_HOME | log; flag=${PIPESTATUS[0]}
    echo "setting up domain.xml for EAP 8" | log; flag=${PIPESTATUS[0]}
    echo HOST_VM_IP=$HOST_VM_IP | log; flag=${PIPESTATUS[0]}

    sudo -u jboss $EAP_HOME/bin/jboss-cli.sh --echo-command \
'embed-host-controller --std-out=echo --domain-config=domain.xml --host-config=host-primary.xml',\
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
"/host=primary/subsystem=elytron/http-authentication-factory=management-http-authentication:write-attribute(name=mechanism-configurations,value=[{mechanism-name=DIGEST,mechanism-realm-configurations=[{realm-name=ManagementRealm}]}])",\
"/host=primary/interface=unsecure:add(inet-address=${HOST_VM_IP})",\
"/host=primary/interface=management:write-attribute(name=inet-address, value=${HOST_VM_IP})",\
"/host=primary/interface=public:add(inet-address=${HOST_VM_IP})" | log; flag=${PIPESTATUS[0]}
else
    echo "EAP_HOME is" $EAP_HOME | log; flag=${PIPESTATUS[0]}
    echo "setting up domain.xml for EAP 7" | log; flag=${PIPESTATUS[0]}
    echo HOST_VM_IP=$HOST_VM_IP | log; flag=${PIPESTATUS[0]}

    sudo -u jboss $EAP_HOME/bin/jboss-cli.sh --echo-command \
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
"/host=master/subsystem=elytron/http-authentication-factory=management-http-authentication:write-attribute(name=mechanism-configurations,value=[{mechanism-name=DIGEST,mechanism-realm-configurations=[{realm-name=ManagementRealm}]}])",\
"/host=master/interface=unsecure:add(inet-address=${HOST_VM_IP})",\
"/host=master/interface=management:write-attribute(name=inet-address, value=${HOST_VM_IP})",\
"/host=master/interface=public:add(inet-address=${HOST_VM_IP})" | log; flag=${PIPESTATUS[0]}
fi

####################### Save domain.xml to file share services for slave hosts.
yum install update -y
yum install cifs-utils -y
mountFileShare
copyDomainXmlFileToShare

####################### Configure the JBoss server and setup eap service
echo "Setting configurations in $EAP_RPM_CONF_DOMAIN"

if [[ "${JDK_VERSION,,}" == "eap8-openjdk17" || "${JDK_VERSION,,}" == "eap8-openjdk11" ]]; then
    echo -e "\t-> WILDFLY_HOST_CONFIG=host-primary.xml" | log; flag=${PIPESTATUS[0]}
    echo 'WILDFLY_HOST_CONFIG=host-primary.xml' >> $EAP_RPM_CONF_DOMAIN | log; flag=${PIPESTATUS[0]}

    ####################### Start the JBoss server and setup eap service
    echo "Start JBoss-EAP service"                  | log; flag=${PIPESTATUS[0]}
    echo "systemctl enable eap8-domain.service" | log; flag=${PIPESTATUS[0]}
    systemctl enable eap8-domain.service        | log; flag=${PIPESTATUS[0]}
    ####################### 

    ###################### Editing eap8-domain.services
    echo "Adding - After=syslog.target network.target NetworkManager-wait-online.service" | log; flag=${PIPESTATUS[0]}
    sed -i 's/After=syslog.target network.target/After=syslog.target network.target NetworkManager-wait-online.service/' /usr/lib/systemd/system/eap8-domain.service | log; flag=${PIPESTATUS[0]}
    echo "Adding - Wants=NetworkManager-wait-online.service \nBefore=httpd.service" | log; flag=${PIPESTATUS[0]}
    sed -i 's/Before=httpd.service/Wants=NetworkManager-wait-online.service \nBefore=httpd.service/' /usr/lib/systemd/system/eap8-domain.service | log; flag=${PIPESTATUS[0]}
    # Calculating EAP gracefulShutdownTimeout and passing it the service.
    if  [[ "${gracefulShutdownTimeout,,}" == "-1"  ]]; then
        sed -i 's/Environment="WILDFLY_OPTS="/Environment="WILDFLY_OPTS="\nTimeoutStopSec=infinity/' /usr/lib/systemd/system/eap8-standalone.service | log; flag=${PIPESTATUS[0]}
    else
        timeoutStopSec=$gracefulShutdownTimeout+20
        if  "${timeoutStopSec}">90; then
        sed -i 's/Environment="WILDFLY_OPTS="/Environment="WILDFLY_OPTS="\nTimeoutStopSec='${timeoutStopSec}'/' /usr/lib/systemd/system/eap8-standalone.service | log; flag=${PIPESTATUS[0]}
        fi
    fi
    systemd-analyze verify --recursive-errors=no /usr/lib/systemd/system/eap8-standalone.service
    echo "Removing - User=jboss Group=jboss" | log; flag=${PIPESTATUS[0]}
    echo "systemctl daemon-reload" | log; flag=${PIPESTATUS[0]}
    systemctl daemon-reload | log; flag=${PIPESTATUS[0]}

    echo "systemctl restart eap8-domain.service"| log; flag=${PIPESTATUS[0]}
    systemctl restart eap8-domain.service       | log; flag=${PIPESTATUS[0]}
    echo "systemctl status eap8-domain.service" | log; flag=${PIPESTATUS[0]}
    systemctl status eap8-domain.service        | log; flag=${PIPESTATUS[0]}
    ######################

    echo "Configuring JBoss EAP management user..." | log; flag=${PIPESTATUS[0]}
    echo "$EAP_HOME/bin/add-user.sh -u JBOSS_EAP_USER -p JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup'" | log; flag=${PIPESTATUS[0]}
    $EAP_HOME/bin/add-user.sh  -u $JBOSS_EAP_USER -p $JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup' | log; flag=${PIPESTATUS[0]}
    if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP management user configuration Failed" >&2 log; exit $flag;  fi

else
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
    echo "Removing - User=jboss Group=jboss" | log; flag=${PIPESTATUS[0]}
    echo "systemctl daemon-reload" | log; flag=${PIPESTATUS[0]}
    systemctl daemon-reload | log; flag=${PIPESTATUS[0]}

    echo "systemctl restart eap7-domain.service"| log; flag=${PIPESTATUS[0]}
    systemctl restart eap7-domain.service       | log; flag=${PIPESTATUS[0]}
    echo "systemctl status eap7-domain.service" | log; flag=${PIPESTATUS[0]}
    systemctl status eap7-domain.service        | log; flag=${PIPESTATUS[0]}
    ######################

    echo "Configuring JBoss EAP management user..." | log; flag=${PIPESTATUS[0]}
    echo "$EAP_HOME/bin/add-user.sh -u JBOSS_EAP_USER -p JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup'" | log; flag=${PIPESTATUS[0]}
    $EAP_HOME/bin/add-user.sh  -u $JBOSS_EAP_USER -p $JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup' | log; flag=${PIPESTATUS[0]}
    if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP management user configuration Failed" >&2 log; exit $flag;  fi
fi
# Seeing a race condition timing error so sleep to delay
sleep 20

echo "Red Hat JBoss EAP Cluster Intallation End " | log; flag=${PIPESTATUS[0]}
/bin/date +%H:%M:%S | log
