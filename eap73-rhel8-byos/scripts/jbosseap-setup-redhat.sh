#!/bin/sh

adddate() {
    while IFS= read -r line; do
        printf '%s %s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$line";
    done
}

JBOSS_EAP_USER=$1
JBOSS_EAP_PASSWORD=$2
RHSM_USER=$3
RHSM_PASSWORD=$4
RHSM_EAPPOOL=$5
RHSM_RHELPOOL=$6

export EAP_HOME="/opt/rh/eap7/root/usr/share/wildfly"
export EAP_RPM_CONF_STANDALONE="/etc/opt/rh/eap7/wildfly/eap7-standalone.conf"

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

if [ "$RHSM_EAPPOOL" != "$RHSM_RHELPOOL" ]; then
    echo "Subscribing the system to get access to RHEL repos" | adddate >> /var/log/jbosseap.install.log
    subscription-manager attach --pool=${RHSM_RHELPOOL} >> /var/log/jbosseap.install.log 2>&1
    flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Pool Attach for RHEL Failed" | adddate  >> /var/log/jbosseap.install.log; exit $flag;  fi
else
    echo "Using the same pool to get access to RHEL repos" | adddate >> /var/log/jbosseap.install.log
fi

# Install JBoss EAP 7.3
echo "subscription-manager repos --enable=jb-eap-7.3-for-rhel-8-x86_64-rpms" | adddate >> /var/log/jbosseap.install.log
subscription-manager repos --enable=jb-eap-7.3-for-rhel-8-x86_64-rpms >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Enabling repos for JBoss EAP Failed" | adddate >> /var/log/jbosseap.install.log; exit $flag;  fi

echo "Installing JBoss EAP 7.3 repos" | adddate >> /var/log/jbosseap.install.log
echo "yum groupinstall -y jboss-eap7" | adddate >> /var/log/jbosseap.install.log
yum groupinstall -y jboss-eap7 >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP installation Failed" | adddate >> /var/log/jbosseap.install.log; exit $flag;  fi

echo "Start JBoss-EAP service" | adddate >> /var/log/jbosseap.install.log
echo "systemctl enable eap7-standalone.service" | adddate >> /var/log/jbosseap.install.log
systemctl enable eap7-standalone.service | adddate >> /var/log/jbosseap.install.log 2>&1
echo "echo "WILDFLY_OPTS=-Djboss.bind.address.management=0.0.0.0" >> ${EAP_RPM_CONF_STANDALONE}" | adddate >> /var/log/jbosseap.install.log
echo 'WILDFLY_OPTS="-Djboss.bind.address.management=0.0.0.0"' >> ${EAP_RPM_CONF_STANDALONE} | adddate >> /var/log/jbosseap.install.log 2>&1

echo "systemctl restart eap7-standalone.service" | adddate >> /var/log/jbosseap.install.log
systemctl restart eap7-standalone.service | adddate >> /var/log/jbosseap.install.log 2>&1
echo "systemctl status eap7-standalone.service" | adddate >> /var/log/jbosseap.install.log
systemctl status eap7-standalone.service | adddate >> /var/log/jbosseap.install.log 2>&1

# Open Red Hat software firewall for port 8080 and 9990:
echo "firewall-cmd --zone=public --add-port=8080/tcp --permanent" | adddate >> /var/log/jbosseap.install.log
firewall-cmd --zone=public --add-port=8080/tcp --permanent | adddate >> /var/log/jbosseap.install.log 2>&1
echo "firewall-cmd --zone=public --add-port=9990/tcp --permanent" | adddate >> /var/log/jbosseap.install.log
firewall-cmd --zone=public --add-port=9990/tcp --permanent | adddate  >> /var/log/jbosseap.install.log 2>&1
echo "firewall-cmd --reload" | adddate >> /var/log/jbosseap.install.log
firewall-cmd --reload | adddate >> /var/log/jbosseap.install.log 2>&1

# Open Red Hat software firewall for port 22:
echo "firewall-cmd --zone=public --add-port=22/tcp --permanent" | adddate >> /var/log/jbosseap.install.log
firewall-cmd --zone=public --add-port=22/tcp --permanent | adddate >> /var/log/jbosseap.install.log 2>&1
echo "firewall-cmd --reload" | adddate >> /var/log/jbosseap.install.log
firewall-cmd --reload | adddate >> /var/log/jbosseap.install.log 2>&1

/bin/date +%H:%M:%S >> /var/log/jbosseap.install.log
echo "Configuring JBoss EAP management user" | adddate >> /var/log/jbosseap.install.log
echo "$EAP_HOME/bin/add-user.sh -u JBOSS_EAP_USER -p JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup'" | adddate >> /var/log/jbosseap.install.log
$EAP_HOME/bin/add-user.sh -u $JBOSS_EAP_USER -p $JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup' >> /var/log/jbosseap.install.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP management user configuration Failed" | adddate >> /var/log/jbosseap.install.log; exit $flag;  fi 

# Seeing a race condition timing error so sleep to delay
sleep 20

echo "ALL DONE!" | adddate >> /var/log/jbosseap.install.log
/bin/date +%H:%M:%S >> /var/log/jbosseap.install.log