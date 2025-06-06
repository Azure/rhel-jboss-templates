#!/bin/bash
set -Eeuo pipefail

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

wait_image_deployment_complete() {
    application_name=$1
    project_name=$2
    logFile=$3

    cnt=0
    read -r -a replicas <<< `oc get wildflyserver ${application_name} -n ${project_name} -o=jsonpath='{.spec.replicas}{" "}{.status.replicas}{"\n"}'`
    while [[ ${#replicas[@]} -ne 2 || ${replicas[0]} != ${replicas[1]} ]]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile
            return 1
        fi
        cnt=$((cnt+1))
        # Delete pods in ImagePullBackOff status
        podIds=`oc get pod -n ${project_name} | grep ImagePullBackOff | awk '{print $1}'`
        read -r -a podIds <<< `echo $podIds`
        for podId in "${podIds[@]}"
        do
            echo "Delete pod ${podId} in ImagePullBackOff status" >> $logFile
            oc delete pod ${podId} -n ${project_name}
        done
        sleep 5
        echo "Wait until the deploymentConfig ${application_name} completes, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        read -r -a replicas <<< `oc get wildflyserver ${application_name} -n ${project_name} -o=jsonpath='{.spec.replicas}{" "}{.status.replicas}{"\n"}'`
    done
    echo "Deployment ${application_name} completed." >> $logFile
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

wait_resource_applied() {
    resourceYamlName=$1
    logFile=$2

    cnt=0
    oc apply -f $resourceYamlName >> $logFile
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile
            return 1
        fi
        cnt=$((cnt+1))

        echo "Failed to apply the resource YAML file ${resourceYamlName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc apply -f $resourceYamlName >> $logFile
    done
    echo "Successfully applied the resource YAML file ${resourceYamlName}"
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

wait_subscription_created() {
    subscriptionName=$1
    namespaceName=$2
    deploymentYaml=$3
    logFile=$4

    cnt=0
    echo "wait_subscription_created--01"
    oc get packagemanifests -n openshift-marketplace | grep ${subscriptionName}
    echo "wait_subscription_created--02"
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile
            return 1
        fi
        cnt=$((cnt+1))

        echo "Unable to get the operator package manifest ${subscriptionName} from OperatorHub, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc get packagemanifests -n openshift-marketplace | grep ${subscriptionName}
    done
    echo "wait_subscription_created--03"
    cnt=0
    echo "wait_subscription_created--04"
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
    echo "wait_subscription_created--05"
    cnt=0
    echo "wait_subscription_created--06"
    oc get subscription ${subscriptionName} -n ${namespaceName}
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile
            return 1
        fi
        cnt=$((cnt+1))

        echo "Unable to get the operator subscription ${subscriptionName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc get subscription ${subscriptionName} -n ${namespaceName}
    done
    echo "wait_subscription_created--07"
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

install_and_config_helm() {
    # Install the Helm CLI
    echo "Install the Helm CLI" >> $logFile
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh

    # Add the JBoss EAP Helm chart repository
    helm repo add jboss-eap https://jbossas.github.io/eap-charts/
}

# Define variables
logFile=/var/log/eap-aro-deployment-${SUFFIX}.log

# Install utilities
apk update
apk add gettext
apk add apache2-utils

# if the environment value CREATE_CLUSTER is true, wait 10 minuts for the cluster to be ready
if [[ "${CREATE_CLUSTER,,}" == "true" ]]; then
    echo "Waiting for 10 minutes for the cluster to be ready" >> $logFile
    sleep 600
fi

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
  echo "Failed to sign into the cluster with ${kubeadminUsername}." >> $logFile
  exit 1
fi

install_and_config_helm

echo ${PULL_SECRET} | base64 -d > ./my-pull-secret.json
echo "Using pull secret from environment variable PULL_SECRET" >> $logFile
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=./my-pull-secret.json

if [[ $? -ne 0 ]]; then
  echo "Failed to create the catalog secret." >> $logFile
  exit 1
fi


# Create subscption and install operator
wait_resource_applied redhat-catalog.yaml $logFile

wait_subscription_created eap openshift-operators eap-operator-sub.yaml ${logFile}
if [[ $? -ne 0 ]]; then
  echo "Failed to install the JBoss EAP Operator from the OperatorHub." >> $logFile
  exit 1
fi

# Check deployment is succeed
wait_deployment_complete eap-operator openshift-operators ${logFile}
if [[ $? -ne 0 ]]; then
  echo "The JBoss EAP Operator is not available." >> $logFile
  exit 1
fi

if [[ "${DEPLOY_APPLICATION,,}" == "true" ]]; then

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

    oc create secret docker-registry pull-secret-${SUFFIX} \
    	--docker-server=registry.redhat.io \
    	--docker-username=${CON_REG_ACC_USER_NAME} \
    	--docker-password=${CON_REG_ACC_PWD}

    helmDeploymentTemplate=helm.yaml.template
    helmDeploymentFile=helm.yaml
    envsubst < "$helmDeploymentTemplate" > "$helmDeploymentFile"

    echo "Using helm chart to build images, APPLICATION_NAME=${APPLICATION_NAME}, PROJECT_NAME=${PROJECT_NAME}" >> $logFile
    helm install ${APPLICATION_NAME} -f helm.yaml jboss-eap/eap8 --namespace ${PROJECT_NAME} >> $logFile

    # Create image deployment YAML file
    echo "Create image deployment YAML file" >> $logFile
    appDeploymentTemplate=app-deployment.yaml.template >> $logFile
    appDeploymentFile=app-deployment.yaml >> $logFile
    envsubst < "$appDeploymentTemplate" > "$appDeploymentFile"

    # Apply image deployment file
    echo "Apply image deployment file" >> $logFile
    wait_file_based_creation ${appDeploymentFile} ${logFile}
    if [[ $? != 0 ]]; then
        echo "Failed to apply image deployment file." >&2
        exit 1
    fi

    # Wait image deployment
    echo "Wait image deployment" >> $logFile
    wait_image_deployment_complete ${APPLICATION_NAME} ${PROJECT_NAME} $logFile

    # Get the route of the application
    echo "Get the route of the application" >> $logFile
    oc expose svc/${APPLICATION_NAME}
    wait_route_available "${APPLICATION_NAME}-route" ${PROJECT_NAME} $logFile
    if [[ $? -ne 0 ]]; then
        echo "The route ${APPLICATION_NAME} is not available." >> $logFile
        exit 1
    fi
fi

appEndpoint=$(oc get route "${APPLICATION_NAME}-route" -n ${PROJECT_NAME} -o=jsonpath='{.spec.host}')

# Write outputs to deployment script output path
result=$(jq -n -c --arg consoleUrl $consoleUrl '{consoleUrl: $consoleUrl}')
if [[ "${DEPLOY_APPLICATION,,}" == "true" ]]; then
    result=$(echo "$result" | jq --arg appEndpoint "http://$appEndpoint" '{"appEndpoint": $appEndpoint} + .')
fi
echo "Result is: $result" >> $logFile
echo $result > $AZ_SCRIPTS_OUTPUT_PATH
