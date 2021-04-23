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

    echo "firewall-cmd --zone=public --add-port=$port/tcp  --permanent" | log_info 
    sudo firewall-cmd  --zone=public --add-port=$port/tcp  --permanent  2>log_err | log_info 
}

JBOSS_EAP_USER=$1
JBOSS_EAP_PASSWORD=$2
RHSM_USER=$3
RHSM_PASSWORD=$4
RHSM_EAPPOOL=$5
RHSM_RHELPOOL=$6

export EAP_HOME="/opt/rh/eap7/root/usr/share/wildfly"
export EAP_RPM_CONF_STANDALONE="/etc/opt/rh/eap7/wildfly/eap7-standalone.conf"
export EAP_LAUNCH_CONFIG="/opt/rh/eap7/root/usr/share/wildfly/bin/standalone.conf"

echo 'export EAP_HOME="/opt/rh/eap7/root/usr/share/wildfly"' >> ~/.bash_profile
echo 'export EAP_RPM_CONF_STANDALONE="/etc/opt/rh/eap7/wildfly/eap7-standalone.conf"' >> ~/.bash_profile
source ~/.bash_profile
touch /etc/profile.d/eap_env.sh
echo 'export EAP_HOME="/opt/rh/eap7/root/usr/share/wildfly"' >> /etc/profile.d/eap_env.sh
echo 'export EAP_RPM_CONF_STANDALONE="/etc/opt/rh/eap7/wildfly/eap7-standalone.conf"' >> /etc/profile.d/eap_env.sh

echo "Initial JBoss EAP 7.3 setup" | log_info 
echo "subscription-manager register --username RHSM_USER --password RHSM_PASSWORD" | log_info 
subscription-manager register --username $RHSM_USER --password $RHSM_PASSWORD  2>log_err | log_info 
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Red Hat Subscription Manager Registration Failed" | log_info ; exit $flag;  fi

echo "Subscribing the system to get access to JBoss EAP 7.3 repos ($RHSM_EAPPOOL)" | log_info 
echo "subscription-manager attach --pool=EAP_POOL" | log_info  
subscription-manager attach --pool=${RHSM_EAPPOOL} 2>log_err | log_info 
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Pool Attach for JBoss EAP Failed" | log_info  ; exit $flag;  fi

if [ "$RHSM_EAPPOOL" != "$RHSM_RHELPOOL" ]; then
    echo "Subscribing the system to get access to RHEL repos ($RHSM_RHELPOOL)" | log_info 
    subscription-manager attach --pool=${RHSM_RHELPOOL}  2>log_err | log_info 
    flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Pool Attach for RHEL Failed" | log_info  ; exit $flag;  fi
else
    echo "Using the same pool to get access to RHEL repos" | log_info 
fi

# Install JBoss EAP 7.3
echo "subscription-manager repos --enable=jb-eap-7.3-for-rhel-8-x86_64-rpms"     | log_info 
subscription-manager repos --enable=jb-eap-7.3-for-rhel-8-x86_64-rpms  2>log_err | log_info 
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Enabling repos for JBoss EAP Failed" | log_info ; exit $flag;  fi

echo "Installing JBoss EAP 7.3 repos"       | log_info 
echo "yum groupinstall -y jboss-eap7"       | log_info 
yum groupinstall -y jboss-eap7  2>log_err   | log_info 
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP installation Failed" | log_info ; exit $flag;  fi


echo "Updating standalone.xml"      | log_info 
echo -e "\t stack UDP to TCP"       | log_info 

sudo -u jboss $EAP_HOME/bin/jboss-cli.sh --echo-command \
"embed-server --std-out=echo  --server-config=standalone.xml",\
'/subsystem=jgroups/channel=ee:write-attribute(name="stack", value="tcp")' 2>log_err | log_info  

####################### Configure the JBoss server and setup eap service
echo "Setting configurations in $EAP_RPM_CONF_STANDALONE"
echo -e "\t-> WILDFLY_SERVER_CONFIG=standalone.xml" | log_info 
echo 'WILDFLY_SERVER_CONFIG=standalone.xml' >> $EAP_RPM_CONF_STANDALONE 2>log_err | log_info

echo "Setting configurations in $EAP_LAUNCH_CONFIG"
echo -e '\t-> JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address=0.0.0.0"' | log_info 
echo -e '\t-> JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address.management=0.0.0.0"' | log_info 
echo -e '\t-> JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address.private=$(hostname -I)"' | log_info 

echo -e 'JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address=0.0.0.0"' >> $EAP_RPM_CONF_STANDALONE 2>log_err | log_info
echo -e 'JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address.management=0.0.0.0"' >> $EAP_RPM_CONF_STANDALONE 2>log_err | log_info
echo -e 'JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address.private=$(hostname -I)"' >> $EAP_LAUNCH_CONFIG 2>log_err | log_info
echo -e 'JAVA_OPTS="$JAVA_OPTS -Djava.net.preferIPv4Stack=true"' >> $EAP_LAUNCH_CONFIG | log_info

echo -e JAVA_OPTS='$JAVA_OPTS' -Djboss.jgroups.azure_ping.storage_account_name=$STORAGE_ACCOUNT_NAME >> $EAP_LAUNCH_CONFIG | log_info 
echo -e JAVA_OPTS='$JAVA_OPTS' -Djboss.jgroups.azure_ping.storage_access_key=$STORAGE_ACCESS_KEY >> $EAP_LAUNCH_CONFIG | log_info 
echo -e JAVA_OPTS='$JAVA_OPTS' -Djboss.jgroups.azure_ping.container=$CONTAINER_NAME >> $EAP_LAUNCH_CONFIG | log_info 

####################### Start the JBoss server and setup eap service

echo "Start JBoss-EAP service"                  | log_info 
echo "systemctl enable eap7-standalone.service" | log_info 
systemctl enable eap7-standalone.service        2>log_err | log_info


echo "systemctl restart eap7-standalone.service"| log_info 
systemctl restart eap7-standalone.service       2>log_err | log_info
echo "systemctl status eap7-standalone.service" | log_info 
systemctl status eap7-standalone.service        2>log_err | log_info
####################### 

####################### Open Red Hat software firewall for port 8080 and 9990:
openport 8080
openport 9990
openport 9999   # native management
openport 8443   # HTTPS
openport 8009   # AJP
openport 22     # SSH
echo "firewall-cmd --reload" | log_info 
firewall-cmd --reload 2>log_err | log_info

echo "iptables-save" | log_info 
sudo iptables-save   2>log_err | log_info

/bin/date +%H:%M:%S 
echo "Configuring JBoss EAP management user" | log_info 
echo "$EAP_HOME/bin/add-user.sh -u JBOSS_EAP_USER -p JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup'" | log_info 
$EAP_HOME/bin/add-user.sh -u $JBOSS_EAP_USER -p $JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup'  2>log_err | log_info
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP management user configuration Failed" | log_info ; exit $flag;  fi 

# Seeing a race condition timing error so sleep to delay
sleep 20

echo "ALL DONE!" | log_info 
/bin/date +%H:%M:%S 