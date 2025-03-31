#!/bin/bash

# See https://github.com/WASdev/azure.liberty.aro/issues/60
MAX_RETRIES=299

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

wait_subscription_created() {
    subscriptionName=$1
    namespaceName=$2
    deploymentYaml=$3
    logFile=$4

    cnt=0
    oc get packagemanifests -n openshift-marketplace | grep -q ${subscriptionName}
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Unable to get the operator package manifest ${subscriptionName} from OperatorHub, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc get packagemanifests -n openshift-marketplace | grep -q ${subscriptionName}
    done

    cnt=0
    oc apply -f ${deploymentYaml} >> $logFile
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Failed to create the operator subscription ${subscriptionName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc apply -f ${deploymentYaml} >> $logFile
    done

    cnt=0
    oc get subscription ${subscriptionName} -n ${namespaceName} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Unable to get the operator subscription ${subscriptionName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc get subscription ${subscriptionName} -n ${namespaceName} 2>/dev/null
    done
    echo "Subscription ${subscriptionName} created." >> $logFile
}

wait_deployment_complete() {
    deploymentName=$1
    namespaceName=$2
    logFile=$3

    cnt=0
    oc get deployment ${deploymentName} -n ${namespaceName} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Unable to get the deployment ${deploymentName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc get deployment ${deploymentName} -n ${namespaceName} 2>/dev/null
    done
}

wait_route_available() {
    routeName=$1
    namespaceName=$2
    logFile=$3
    cnt=0
    oc get route ${routeName} -n ${namespaceName} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        echo "Unable to get the route ${routeName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc get route ${routeName} -n ${namespaceName} 2>/dev/null
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
    oc new-project ${namespaceName} 2>/dev/null
    oc get project ${namespaceName} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        echo "Unable to create the project ${namespaceName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc new-project ${namespaceName} 2>/dev/null
        oc get project ${namespaceName} 2>/dev/null
    done
}

wait_add_view_role() {
    namespaceName=$1
    logFile=$2
    cnt=0
    oc policy add-role-to-user view system:serviceaccount:${namespaceName}:default -n ${namespaceName} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        echo "Unable to add view role to project ${namespaceName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc policy add-role-to-user view system:serviceaccount:${namespaceName}:default -n ${namespaceName} 2>/dev/null
    done
}

wait_add_scc_privileged() {
    namespaceName=$1
    logFile=$2
    cnt=0
    oc adm policy add-scc-to-user privileged -z default --namespace ${namespaceName} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        echo "Unable to add scc privileged to project default service account of ${namespaceName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc adm policy add-scc-to-user privileged -z default --namespace ${namespaceName} 2>/dev/null
    done
}



wait_file_based_creation() {
    deploymentFile=$1
    logFile=$2
    cnt=0
    oc apply -f ${deploymentFile} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        echo "Unable to apply file, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc apply -f ${deploymentFile} 2>/dev/null
    done
}

wait_secret_link() {
    secretName=$1
    logFile=$2
    cnt=0
    oc secrets link default ${secretName} --for=pull 2>/dev/null
    oc secrets link builder ${secretName} --for=pull 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        echo "Unable to secret link, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc secrets link default ${secretName} --for=pull 2>/dev/null
        oc secrets link builder ${secretName} --for=pull 2>/dev/null
    done
}

# Define variables
logFile=deployment.log

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

# Create subscption and install operator
wait_subscription_created eap openshift-operators eap-operator-sub.yaml ${logFile}

if [[ $? -ne 0 ]]; then
  echo "Failed to install the JBoss EAP Operator from the OperatorHub." >&2
  exit 1
fi

# Check deployment is succeed
wait_deployment_complete eap-operator openshift-operators ${logFile}
if [[ $? -ne 0 ]]; then
  echo "The JBoss EAP Operator is not available." >&2
  exit 1
fi

if [[ "${DEPLOY_APPLICATION,,}" == "true" ]]; then
    # Install the Helm CLI
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    sudo chmod 700 get_helm.sh
    ./get_helm.sh

    # Add the JBoss EAP Helm chart repository
    helm repo add jboss-eap https://jbossas.github.io/eap-charts/

    # Create a new project for managing workload of the user
    wait_project_created ${PROJECT_NAME} ${logFile}
    if [[ $? -ne 0 ]]; then
        echo "Failed to create project ${PROJECT_NAME}." >&2
        exit 1
    fi

    # Enable the privileged containers created by EAP Operator to be successfully deployed
    wait_add_scc_privileged ${PROJECT_NAME} ${logFile}
    if [[ $? -ne 0 ]]; then
        echo "Failed to add scc privileged to default service account of ${PROJECT_NAME}." >&2
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
    secretDeploymentTemplate=red-hat-container-registry-pull-secret.yaml.template >> $logFile 
    secretDeploymentFile=red-hat-container-registry-pull-secret.yaml >> $logFile 
    envsubst < "$secretDeploymentTemplate" > "$secretDeploymentFile"

    # Create secret
    echo "Create secret" >> $logFile
    wait_file_based_creation ${secretDeploymentFile} $logFile
    if [[ $? != 0 ]]; then
        echo "Failed to complete secret creation progress." >&2
        exit 1
    fi

    # Configure the secret for project
    echo "Configure the secret for project" >> $logFile
    wait_secret_link ${CON_REG_SECRET_NAME}-pull-secret $logFile
    if [[ $? != 0 ]]; then
        echo "Failed to configure the secret for project." >&2
        exit 1
    fi

    # Create helm install value deployment YAML file
    echo "Create helm install value deployment YAML file" >> $logFile
    helmDeploymentTemplate=helm.yaml.template >> $logFile
    helmDeploymentFile=helm.yaml >> $logFile
    envsubst < "$helmDeploymentTemplate" > "$helmDeploymentFile"

    helm install ${APPLICATION_NAME} -f helm.yaml jboss-eap/eap8

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
