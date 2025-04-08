#!/bin/bash

# See https://github.com/WASdev/azure.liberty.aro/issues/60
MAX_RETRIES=99
export SUFFIX=$(date +%s)

# Define functions
wait_login_complete() {
    username=$1
    password=$2
    apiServerUrl="$3"
    logFile=$4

    cnt=0
    oc login -u $username -p $password --server="$apiServerUrl" >> $logFile 2>&1
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Login failed with ${username}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc login -u $username -p $password --server="$apiServerUrl" >> $logFile 2>&1
    done
}

wait_route_available() {
    routeName=$1
    namespaceName=$2
    logFile=$3
    cnt=0
    oc get route ${routeName} -n ${namespaceName} >> $logFile 2>&1
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        echo "Unable to get the route ${routeName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc get route ${routeName} -n ${namespaceName} >> $logFile 2>&1
    done
    cnt=0
    appEndpoint=$(oc get route ${routeName} -n ${namespaceName} -o=jsonpath='{.spec.host}')
    echo "appEndpoint is ${appEndpoint}"
    while [[ -z $appEndpoint ]]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        sleep 5
        echo "Wait until the host of route ${routeName} is available, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        appEndpoint=$(oc get route ${routeName} -n ${namespaceName} -o=jsonpath='{.spec.host}')
        echo "appEndpoint is ${appEndpoint}"
    done
}

wait_project_created() {
    namespaceName=$1
    logFile=$2
    cnt=0
    oc new-project ${namespaceName} >> $logFile 2>&1
    oc get project ${namespaceName} >> $logFile 2>&1
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        echo "Unable to create the project ${namespaceName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc new-project ${namespaceName} >> $logFile 2>&1
        oc get project ${namespaceName} >> $logFile 2>&1
    done
}

wait_add_view_role() {
    namespaceName=$1
    logFile=$2
    cnt=0
    oc policy add-role-to-user view system:serviceaccount:${namespaceName}:default -n ${namespaceName} >> $logFile 2>&1
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        echo "Unable to add view role to project ${namespaceName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc policy add-role-to-user view system:serviceaccount:${namespaceName}:default -n ${namespaceName} >> $logFile 2>&1
    done
}

wait_add_scc_privileged() {
    namespaceName=$1
    logFile=$2
    cnt=0
    oc adm policy add-scc-to-user privileged -z default --namespace ${namespaceName} >> $logFile 2>&1
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        echo "Unable to add scc privileged to project default service account of ${namespaceName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc adm policy add-scc-to-user privileged -z default --namespace ${namespaceName} >> $logFile 2>&1
    done
}

wait_file_based_creation() {
    deploymentFile=$1
    logFile=$2
    cnt=0
    echo "Applying ${deploymentFile} ..." >> $logFile
    oc apply -f ${deploymentFile} >> $logFile
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        echo "Unable to apply file, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc apply -f ${deploymentFile} >> $logFile 2>&1
    done
}

wait_secret_link() {
    secretName=$1
    logFile=$2
    cnt=0
    oc secrets link default ${secretName} --for=pull >> $logFile 2>&1
    oc secrets link builder ${secretName} --for=pull >> $logFile 2>&1
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        echo "Unable to secret link, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc secrets link default ${secretName} --for=pull >> $logFile 2>&1
        oc secrets link builder ${secretName} --for=pull >> $logFile 2>&1
    done
}

# Define variables
logFile=/var/log/eap-aro-deployment.log

# Install utilities
apk update
apk add gettext
apk add apache2-utils

# Check if /usr/lib/libresolv.so.2 exists that is required by the OpenShift CLI
if [ ! -f /usr/lib/libresolv.so.2 ]; then
    echo "Install gcompat package which provides /usr/lib/libresolv.so.2"
    apk add gcompat

    echo "Create a symbolic link for /usr/lib/libresolv.so.2"
    ln -sf /lib/libgcompat.so.0 /usr/lib/libresolv.so.2
fi

# Retrieve cluster credentials and api/console URLs
credentials=$(az aro list-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME -o json)
kubeadminUsername=$(echo $credentials | jq -r '.kubeadminUsername')
kubeadminPassword=$(echo $credentials | jq -r '.kubeadminPassword')
apiServerUrl=$(az aro show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query 'apiserverProfile.url' -o tsv)
consoleUrl=$(az aro show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query 'consoleProfile.url' -o tsv)

# Install the OpenShift CLI
downloadUrl=$(echo $consoleUrl | sed -e "s/https:\/\/console/https:\/\/downloads/g")
wget --no-check-certificate ${downloadUrl}amd64/linux/oc.tar -q -P ~
mkdir ~/openshift
tar xvf ~/oc.tar -C ~/openshift
echo 'export PATH=$PATH:~/openshift' >> ~/.bash_profile && source ~/.bash_profile

# Sign in to cluster
wait_login_complete $kubeadminUsername $kubeadminPassword "$apiServerUrl" $logFile
if [[ $? -ne 0 ]]; then
  echo "Failed to sign into the cluster with ${kubeadminUsername}." >&2
  exit 1
fi

if [[ "${DEPLOY_APPLICATION,,}" == "true" ]]; then
    # Install the Helm CLI
    echo "Install the Helm CLI" >> $logFile
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh

    # Add the JBoss EAP Helm chart repository
    helm repo add jboss-eap https://jbossas.github.io/eap-charts/

    # Create a new project for managing workload of the user
    echo "Creating Project ${PROJECT_NAME}" >> $logFile
    wait_project_created ${PROJECT_NAME} ${logFile}
    if [[ $? -ne 0 ]]; then
        echo "Failed to create project ${PROJECT_NAME}." >> $logFile
        exit 1
    fi

    wait_add_scc_privileged ${PROJECT_NAME} ${logFile}
    if [[ $? -ne 0 ]]; then
        echo "Failed to add scc privileged to default service account of ${PROJECT_NAME}." >> $logFile
        exit 1
    fi

    # Enable the containers to "view" the namespace
    wait_add_view_role ${PROJECT_NAME} ${logFile}
    if [[ $? -ne 0 ]]; then
        echo "Add view role to ${PROJECT_NAME}." >&2
        exit 1
    fi
    
    oc project ${PROJECT_NAME}

    # Create secret YAML file
    echo "Create secret YAML file" >> $logFile
    secretDeploymentTemplate=red-hat-container-registry-pull-secret.yaml.template
    secretDeploymentFile=red-hat-container-registry-pull-secret.yaml
    envsubst < "$secretDeploymentTemplate" > "$secretDeploymentFile"

    # Create secret
    echo "Creating secret start ..." >> $logFile
    wait_file_based_creation ${secretDeploymentFile} $logFile
    if [[ $? != 0 ]]; then
        echo "Failed to complete secret creation progress." >&2
        exit 1
    fi
    echo "Creating secret end ..." >> $logFile

    # Configure the secret for project
    echo "Configure the secret for project" >> $logFile
    wait_secret_link ${CON_REG_SECRET_NAME}-pull-secret $logFile
    if [[ $? != 0 ]]; then
        echo "Failed to configure the secret for project." >&2
        exit 1
    fi

    # Create helm install value deployment YAML file
    echo "Creating helm install value deployment YAML file" >> $logFile
    helmDeploymentTemplate=helm.yaml.template
    helmDeploymentFile=helm.yaml
    envsubst < "$helmDeploymentTemplate" > "$helmDeploymentFile"

    echo "Using helm chart to deploy JBoss EAP, APPLICATION_NAME=${APPLICATION_NAME}, PROJECT_NAME=${PROJECT_NAME}" >> $logFile
    helm install ${APPLICATION_NAME} -f helm.yaml jboss-eap/eap8 --namespace ${PROJECT_NAME} >> $logFile

    # Get the route of the application
    echo "Get the route of the application" >> $logFile
    oc expose svc/${APPLICATION_NAME}-loadbalancer
    appEndpoint=
    wait_route_available ${APPLICATION_NAME}-loadbalancer ${PROJECT_NAME} $logFile
    if [[ $? -ne 0 ]]; then
        echo "The route ${APPLICATION_NAME} is not available." >> $logFile
        exit 1
    fi
    echo "appEndpoint is ${appEndpoint}"
fi

# Write outputs to deployment script output path
result=$(jq -n -c --arg consoleUrl $consoleUrl '{consoleUrl: $consoleUrl}')
if [[ "${DEPLOY_APPLICATION,,}" == "true" ]]; then
    result=$(echo "$result" | jq --arg appEndpoint "http://$appEndpoint" '{"appEndpoint": $appEndpoint} + .')
fi
echo "Result is: $result" >> $logFile
echo $result > $AZ_SCRIPTS_OUTPUT_PATH
