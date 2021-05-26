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

adddate() {
    while IFS= read -r line; do
        printf '%s %s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$line";
    done
}

openport() {
    port=$1

    echo "firewall-cmd --zone=public --add-port=$port/tcp  --permanent"  | adddate >> /var/log/jbosseap.install.log
    sudo firewall-cmd  --zone=public --add-port=$port/tcp  --permanent   | adddate >> /var/log/jbosseap.install.log 2>&1
}

JBOSS_EAP_USER=$1
JBOSS_EAP_PASSWORD=$2
RHSM_USER=$3
RHSM_PASSWORD=$4
RHSM_EAPPOOL=$5

export EAP_HOME="/opt/rh/eap7/root/usr/share/wildfly"
export EAP_RPM_CONF_STANDALONE="/etc/opt/rh/eap7/wildfly/eap7-standalone.conf"
export EAP_LAUNCH_CONFIG="/opt/rh/eap7/root/usr/share/wildfly/bin/standalone.conf"

echo 'export EAP_HOME="/opt/rh/eap7/root/usr/share/wildfly"' >> ~/.bash_profile
echo 'export EAP_RPM_CONF_STANDALONE="/etc/opt/rh/eap7/wildfly/eap7-standalone.conf"' >> ~/.bash_profile
source ~/.bash_profile
touch /etc/profile.d/eap_env.sh
echo 'export EAP_HOME="/opt/rh/eap7/root/usr/share/wildfly"' >> /etc/profile.d/eap_env.sh
echo 'export EAP_RPM_CONF_STANDALONE="/etc/opt/rh/eap7/wildfly/eap7-standalone.conf"' >> /etc/profile.d/eap_env.sh

echo "Initial JBoss EAP 7.3 setup" | adddate >> /var/log/jbosseap.install.log
echo "subscription-manager register --username RHSM_USER --password RHSM_PASSWORD" | adddate >> /var/log/jbosseap.install.log
subscription-manager register --username $RHSM_USER --password $RHSM_PASSWORD >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Red Hat Subscription Manager Registration Failed" | adddate >> /var/log/jbosseap.install.log; exit $flag;  fi

echo "Subscribing the system to get access to JBoss EAP 7.3 repos" | adddate >> /var/log/jbosseap.install.log
echo "subscription-manager attach --pool=EAP_POOL" | adddate  >> /var/log/jbosseap.install.log
subscription-manager attach --pool=${RHSM_EAPPOOL} >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Pool Attach for JBoss EAP Failed" | adddate  >> /var/log/jbosseap.install.log; exit $flag;  fi

# Install JBoss EAP 7.3
echo "subscription-manager repos --enable=jb-eap-7.3-for-rhel-8-x86_64-rpms" | adddate >> /var/log/jbosseap.install.log
subscription-manager repos --enable=jb-eap-7.3-for-rhel-8-x86_64-rpms >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Enabling repos for JBoss EAP Failed" | adddate >> /var/log/jbosseap.install.log; exit $flag;  fi

echo "Installing JBoss EAP 7.3 repos" | adddate >> /var/log/jbosseap.install.log
echo "yum groupinstall -y jboss-eap7" | adddate >> /var/log/jbosseap.install.log
yum groupinstall -y jboss-eap7 >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP installation Failed" | adddate >> /var/log/jbosseap.install.log; exit $flag;  fi

echo "Updating standalone.xml" | adddate >> /var/log/jbosseap.install.log
echo -e "\t stack UDP to TCP"           | adddate >> /var/log/jbosseap.install.log

sudo -u jboss $EAP_HOME/bin/jboss-cli.sh --echo-command \
'embed-server --std-out=echo  --server-config=standalone.xml',\
'/subsystem=jgroups/channel=ee:write-attribute(name="stack", value="tcp")' | adddate >> /var/log/jbosseap.install.log 2>&1

####################### Configure the JBoss server and setup eap service
echo "Setting configurations in $EAP_RPM_CONF_STANDALONE"
echo -e "\t-> WILDFLY_SERVER_CONFIG=standalone.xml" | log_info 
echo 'WILDFLY_SERVER_CONFIG=standalone.xml' >> $EAP_RPM_CONF_STANDALONE 2>log_err | log_info

echo "Setting configurations in $EAP_LAUNCH_CONFIG"
echo -e '\t-> JAVA_OPTS=$JAVA_OPTS -Djboss.bind.address=0.0.0.0' | log_info 
echo -e '\t-> JAVA_OPTS=$JAVA_OPTS -Djboss.bind.address.management=0.0.0.0' | log_info 
echo -e '\t-> JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address.private=$(hostname -I)"' | log_info 
echo -e '\t-> JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address.private=$(hostname -I)"' | log_info 

echo -e 'JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address=0.0.0.0"' >> $EAP_LAUNCH_CONFIG 2>log_err | log_info
echo -e 'JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address.management=0.0.0.0"' >> $EAP_LAUNCH_CONFIG 2>log_err | log_info
echo -e 'JAVA_OPTS="$JAVA_OPTS -Djboss.bind.address.private=$(hostname -I)"' >> $EAP_LAUNCH_CONFIG 2>log_err | log_info
echo -e 'JAVA_OPTS="$JAVA_OPTS -Djava.net.preferIPv4Stack=true"' >> $EAP_LAUNCH_CONFIG | log_info

echo -e "JAVA_OPTS=\"\$JAVA_OPTS -Djboss.jgroups.azure_ping.storage_account_name=$STORAGE_ACCOUNT_NAME\"" >> $EAP_LAUNCH_CONFIG | log_info 
echo -e "JAVA_OPTS=\"\$JAVA_OPTS -Djboss.jgroups.azure_ping.storage_access_key=$STORAGE_ACCESS_KEY\"" >> $EAP_LAUNCH_CONFIG | log_info 
echo -e "JAVA_OPTS=\"\$JAVA_OPTS -Djboss.jgroups.azure_ping.container=$CONTAINER_NAME\"" >> $EAP_LAUNCH_CONFIG | log_info  
####################### Start the JBoss server and setup eap service
echo "Start JBoss-EAP service"                  | adddate >> /var/log/jbosseap.install.log
echo "systemctl enable eap7-standalone.service" | adddate >> /var/log/jbosseap.install.log
systemctl enable eap7-standalone.service        | adddate >> /var/log/jbosseap.install.log 2>&1

echo "systemctl restart eap7-standalone.service"| adddate >> /var/log/jbosseap.install.log
systemctl restart eap7-standalone.service       | adddate >> /var/log/jbosseap.install.log 2>&1
echo "systemctl status eap7-standalone.service" | adddate >> /var/log/jbosseap.install.log
systemctl status eap7-standalone.service        | adddate >> /var/log/jbosseap.install.log 2>&1
####################### 

openport 8080
openport 9990
openport 9999
openport 8443
openport 8009
openport 22
echo "firewall-cmd --reload" | adddate >> /var/log/jbosseap.install.log
firewall-cmd --reload | adddate >> /var/log/jbosseap.install.log 2>&1
echo "iptables-save" | adddate >> /var/log/jbosseap.install.log
sudo iptables-save   | adddate >> /var/log/jbosseap.install.log 2>&1

/bin/date +%H:%M:%S >> /var/log/jbosseap.install.log
echo "Configuring JBoss EAP management user" | adddate >> /var/log/jbosseap.install.log
echo "$EAP_HOME/bin/add-user.sh -u JBOSS_EAP_USER -p JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup'" | adddate >> /var/log/jbosseap.install.log
$EAP_HOME/bin/add-user.sh -u $JBOSS_EAP_USER -p $JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup' >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP management user configuration Failed" | adddate >> /var/log/jbosseap.install.log; exit $flag;  fi 

# Seeing a race condition timing error so sleep to delay
sleep 20

echo "ALL DONE!" | adddate >> /var/log/jbosseap.install.log
/bin/date +%H:%M:%S >> /var/log/jbosseap.install.log