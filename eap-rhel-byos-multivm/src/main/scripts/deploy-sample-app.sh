#!/bin/sh
log() {
    while IFS= read -r line; do
        printf '%s %s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$line" >> /var/log/jbosseap.install.log
    done
}

##################### Configure EAP_LAUNCH_CONFIG and EAP_HOME
if [[ "${JDK_VERSION,,}" == "eap8-openjdk17" || "${JDK_VERSION,,}" == "eap8-openjdk11" ]]; then
    export EAP_LAUNCH_CONFIG="/opt/rh/eap8/root/usr/share/wildfly/bin/domain.conf"
    echo 'export EAP_RPM_CONF_DOMAIN="/etc/opt/rh/eap8/wildfly/eap8-domain.conf"' >> ~/.bash_profile
    echo 'export EAP_HOME="/opt/rh/eap8/root/usr/share"' >> ~/.bash_profile
    source ~/.bash_profile
    touch /etc/profile.d/eap_env.sh
    echo 'export EAP_HOME="/opt/rh/eap8/root/usr/share"' >> /etc/profile.d/eap_env.sh
else
    export EAP_LAUNCH_CONFIG="/opt/rh/eap7/root/usr/share/wildfly/bin/domain.conf"
    echo 'export EAP_RPM_CONF_DOMAIN="/etc/opt/rh/eap7/wildfly/eap7-domain.conf"' >> ~/.bash_profile
    echo 'export EAP_HOME="/opt/rh/eap7/root/usr/share"' >> ~/.bash_profile
    source ~/.bash_profile
    touch /etc/profile.d/eap_env.sh
    echo 'export EAP_HOME="/opt/rh/eap7/root/usr/share"' >> /etc/profile.d/eap_env.sh
fi

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

echo "Deploy an application" | log; flag=${PIPESTATUS[0]}
echo "curl -o eap-session-replication.war $fileUrl" | log; flag=${PIPESTATUS[0]}
curl -o "eap-session-replication.war" "$fileUrl" | log; flag=${PIPESTATUS[0]}
if [ $flag != 0 ] ; then echo  "ERROR! Sample Application Download Failed" >&2 log; exit $flag; fi

sudo -u jboss $EAP_HOME/bin/jboss-cli.sh -c "deploy $(pwd)/eap-session-replication.war --server-groups=main-server-group"