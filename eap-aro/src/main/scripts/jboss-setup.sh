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

wait_maven_build_complete() {
    application_name=$1
    logFile=$2
    cnt=0
    isSuccess="false"
    while [[ "${isSuccess,,}" == "false" ]];
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        while IFS= read -r line
        do
            if [[ $line == *"BUILD SUCCESS"* ]]; then
                echo "Found BUILD SUCCESS in log" >> $logFile 
                isSuccess="true"
            fi
        done <<< `oc logs buildconfig/${application_name}-build-artifacts`
        if [[ "${isSuccess,,}" == "false" ]]; then
	        echo "Unable to confirm the Maven build progress, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile 
	        sleep 5
        fi
    done
    echo "Maven build completed." >> $logFile 
}

wait_image_push_complete() {
    application_name=$1
    logFile=$2
    cnt=0
    isSuccess="false"
    while [[ "${isSuccess,,}" == "false" ]];
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        while IFS= read -r line
        do
            if [[ $line == *"Push successful"* ]]; then
                echo "Found Push successful in log" >> $logFile 
                isSuccess="true"
            fi
        done <<< `oc logs buildconfig/${application_name}`
        if [[ "${isSuccess,,}" == "false" ]]; then
	        echo "Unable to confirm the image push progress, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile 
	        sleep 5
        fi
    done
    echo "Image push completed." >> $logFile 
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

wait_scalation_complete() {
    deploymentConfigName=$1
    namespaceName=$2
    logFile=$3

    cnt=0
    read -r -a replicas <<< `oc get deploymentconfig ${deploymentConfigName} -n ${namespaceName} -o=jsonpath='{.spec.replicas}{" "}{.status.readyReplicas}{" "}{.status.availableReplicas}{" "}{.status.updatedReplicas}{"\n"}'`
    while [[ ${#replicas[@]} -ne 4 || ${replicas[0]} != ${replicas[1]} || ${replicas[1]} != ${replicas[2]} || ${replicas[2]} != ${replicas[3]} ]]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        # Delete pods in ImagePullBackOff status
        podIds=`oc get pod -n ${namespaceName} | grep ImagePullBackOff | awk '{print $1}'`
        read -r -a podIds <<< `echo $podIds`
        for podId in "${podIds[@]}"
        do
            echo "Delete pod ${podId} in ImagePullBackOff status" >> $logFile
            oc delete pod ${podId} -n ${namespaceName}
        done
        sleep 5
        echo "Wait until the deploymentConfig ${deploymentConfigName} completes, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        read -r -a replicas <<< `oc get deploymentconfig ${deploymentConfigName} -n ${namespaceName} -o=jsonpath='{.spec.replicas}{" "}{.status.readyReplicas}{" "}{.status.availableReplicas}{" "}{.status.updatedReplicas}{"\n"}'`
    done
    echo "Deployment ${deploymentConfigName} completed." >> $logFile
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

wait_application_created() {
    project_name=$1
    application_name=$2
    src_repo_url=$3
    src_repo_ref=$4
    src_repo_dir=$5
    logFile=$6
    cnt=0
    oc new-app --template=eap74-basic-s2i \
        -p IMAGE_STREAM_NAMESPACE=${project_name} \
        -p APPLICATION_NAME=${application_name} \
        -p EAP_IMAGE_NAME=jboss-eap74-openjdk11-openshift:7.4.0 \
        -p EAP_RUNTIME_IMAGE_NAME=jboss-eap74-openjdk11-runtime-openshift:7.4.0 \
        -p SOURCE_REPOSITORY_URL=${src_repo_url} \
        -p SOURCE_REPOSITORY_REF=${src_repo_ref} \
        -p CONTEXT_DIR=${src_repo_dir} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        echo "Unable to create the application, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc new-app --template=eap74-basic-s2i \
            -p IMAGE_STREAM_NAMESPACE=${project_name} \
            -p APPLICATION_NAME=${application_name} \
            -p EAP_IMAGE_NAME=jboss-eap74-openjdk11-openshift:7.4.0 \
            -p EAP_RUNTIME_IMAGE_NAME=jboss-eap74-openjdk11-runtime-openshift:7.4.0 \
            -p SOURCE_REPOSITORY_URL=${src_repo_url} \
            -p SOURCE_REPOSITORY_REF=${src_repo_ref} \
            -p CONTEXT_DIR=${src_repo_dir} 2>/dev/null
    done
}

wait_file_based_creation() {
    deploymentFile=$1
    logFile=$2
    cnt=0
    oc create -f ${deploymentFile} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        echo "Unable to complete creation, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc create -f ${deploymentFile} 2>/dev/null
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

# Install the OpenShift CLI
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz -q -P ~
mkdir ~/openshift
tar -zxvf ~/openshift-client-linux.tar.gz -C ~/openshift
echo 'export PATH=$PATH:~/openshift' >> ~/.bash_profile && source ~/.bash_profile

# Sign in to cluster
credentials=$(az aro list-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME -o json)
kubeadminUsername=$(echo $credentials | jq -r '.kubeadminUsername')
kubeadminPassword=$(echo $credentials | jq -r '.kubeadminPassword')
apiServerUrl=$(az aro show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query 'apiserverProfile.url' -o tsv)
consoleUrl=$(az aro show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query 'consoleProfile.url' -o tsv)
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
    # Create a new project for managing workload of the user
    wait_project_created ${PROJECT_NAME} ${logFile}
    if [[ $? -ne 0 ]]; then
        echo "Failed to create project ${PROJECT_NAME}." >&2
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

    # Import command for JDK 11, we assume it is the first time
    echo "Import command for JDK 11, we assume it is the first time" >> $logFile
    eap74Openjdk11ImageStream="https://raw.githubusercontent.com/jboss-container-images/jboss-eap-openshift-templates/eap74/eap74-openjdk11-image-stream.json"
    wait_file_based_creation ${eap74Openjdk11ImageStream} $logFile
    if [[ $? != 0 ]]; then
        echo "Failed to import command for JDK 11." >&2
        exit 1
    fi

    # Import command for templates, we assume it is the first time
    echo "Import command for templates, we assume it is the first time" >> $logFile
    for resource in \
        eap74-amq-persistent-s2i.json \
        eap74-amq-s2i.json \
        eap74-basic-s2i.json \
        eap74-https-s2i.json \
        eap74-sso-s2i.json

    do
        echo "Now import ${resource}" >> $logFile
        resourceFile="https://raw.githubusercontent.com/jboss-container-images/jboss-eap-openshift-templates/eap74/templates/${resource}"
        wait_file_based_creation ${resourceFile} $logFile
        if [[ $? != 0 ]]; then
            echo "Failed to import command for JDK 11." >&2
            exit 1
        fi
    done

    # Create a new application
    echo "Create a new application" >> $logFile
    wait_application_created ${PROJECT_NAME} ${APPLICATION_NAME} ${SRC_REPO_URL} ${SRC_REPO_REF} ${SRC_REPO_DIR} $logFile
    if [[ $? != 0 ]]; then
        echo "Failed to complete application creation progress." >&2
        exit 1
    fi

    # Check Maven build progress
    echo "Check Maven build progress" >> $logFile
    wait_maven_build_complete ${APPLICATION_NAME} ${logFile}
    if [[ $? != 0 ]]; then
        echo "Failed to complete Maven build progress." >&2
        exit 1
    fi

    # Check image push progress
    echo "Check image push progress" >> $logFile
    wait_image_push_complete ${APPLICATION_NAME} ${logFile}
    if [[ $? != 0 ]]; then
        echo "Failed to complete image push progress." >&2
        exit 1
    fi

    # Scale up the application instance
    echo "Scale up the application instance" >> $logFile
    oc scale deploymentconfig ${APPLICATION_NAME} --replicas=${APP_REPLICAS} >> $logFile 
    if [[ $? != 0 ]]; then
        echo "Failed to kick off scalation progress." >&2
        exit 1
    fi

    # Wait until the application scalation completes
    wait_scalation_complete ${APPLICATION_NAME} ${PROJECT_NAME} ${logFile}
    if [[ $? != 0 ]]; then
        echo "The application is not available." >> $logFile
        exit 1
    fi

    # Get the route of the application
    echo "Get the route of the application" >> $logFile
    appEndpoint=
    wait_route_available ${APPLICATION_NAME} ${PROJECT_NAME} $logFile
    if [[ $? -ne 0 ]]; then
        echo "The route ${APPLICATION_NAME} is not available." >> $logFile
        exit 1
    fi
    echo "appEndpoint is ${appEndpoint}"
fi

# Write outputs to deployment script output path
result=$(jq -n -c --arg consoleUrl $consoleUrl '{consoleUrl: $consoleUrl}')
if [[ "${DEPLOY_APPLICATION,,}" == "true" ]]; then
    result=$(echo "$result" | jq --arg appEndpoint "$appEndpoint" '{"appEndpoint": $appEndpoint} + .')
fi
echo "Result is: $result" >> $logFile
echo $result > $AZ_SCRIPTS_OUTPUT_PATH
