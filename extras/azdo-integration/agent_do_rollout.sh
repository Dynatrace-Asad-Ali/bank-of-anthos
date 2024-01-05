#!/bin/bash

setDefaultValues() {
    # RELEASE_RELEASENAME is an Azdo Pipeline variable
    if [ -z "$RELEASE_RELEASENAME" ]; then
        echo "\$RELEASE_RELEASENAME is empty"
        RELEASE_RELEASENAME="Release-000"
    fi
    # Default Variabes
    REPOSITORY="gcr.io/sales-engineering-emea/bank-of-anthos"
    VERSION="latest"
    JVM_OPTS="-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -XX:+ExitOnOutOfMemoryError -Xms256m -Xmx512m"
    LOG_LEVEL="info"
    imagePullPolicy="Always"
    APPLICATION="banking"
    ENVIRONMENT="development"
    NAMESPACE=${ENVIRONMENT}-${APPLICATION}
    YAMLFILE=$(date '+%Y-%m-%d_%H_%M_%S').yaml
    RESET_DB=false

    # Release Info from AzDo
    DT_RELEASE_VERSION=$VERSION
    DT_RELEASE_BUILD_VERSION=$RELEASE_RELEASENAME

    # RELEASE ID FROM AZDO
    #RELEASE_RELEASEID=387
    #RELEASE_RELEASENAME=Release-386
}

exportVariables() {
    # Export variables so they are available in the command 'envsubst'
    export REPOSITORY=$REPOSITORY
    export VERSION=$VERSION
    export JVM_OPTS=$JVM_OPTS
    export LOG_LEVEL=$LOG_LEVEL
    export imagePullPolicy=$imagePullPolicy
    export APPLICATION=$APPLICATION
    export ENVIRONMENT=$ENVIRONMENT
    export NAMESPACE=${ENVIRONMENT}-${APPLICATION}
    export DT_RELEASE_VERSION=$VERSION
    export DT_RELEASE_BUILD_VERSION=$DT_RELEASE_BUILD_VERSION
}

printOutput() {
    echo ""
    echo -e "\tApplying  Deployment configuration with the following variables:"
    echo ""
    echo -e "\tREPOSITORY\t\t\t$REPOSITORY"
    echo -e "\tVERSION\t\t\t\t$VERSION"
    echo -e "\tJVM_OPTS\t\t\t$JVM_OPTS"
    echo -e "\tLOG_LEVEL\t\t\t$LOG_LEVEL"
    echo -e "\tRESET_DB\t\t\t$RESET_DB"
    echo -e "\timagePullPolicy\t\t\t$imagePullPolicy"
    echo -e "\tAPPLICATION\t\t\t$APPLICATION"
    echo -e "\tENVIRONMENT\t\t\t$ENVIRONMENT"
    echo -e "\tDT_RELEASE_VERSION\t\t$DT_RELEASE_VERSION"
    echo -e "\tDT_RELEASE_BUILD_VERSION\t$DT_RELEASE_BUILD_VERSION"
    echo -e "\tYAMLFILE\t\t\t$YAMLFILE can be found under 'gen' folder"

}

calculateVersion() {
    #Date in 12 Hour format (01-12)
    h=$(date +"%I")
    case $h in
    "12" | "06")
        VERSION="1.0.0"
        ;;
    "01" | "07")
        VERSION="1.0.1"
        ;;
    "02" | "08")
        VERSION="1.0.2"
        ;;
    "03" | "09")
        VERSION="1.0.0"
        ;;
    "04" | "10")
        VERSION="1.0.1"
        ;;
    "05" | "11")
        VERSION="1.0.2"
        ;;
    esac
    echo "The hour is $h and the Version selected is $VERSION"
}

printDeployments() {
    echo "The new deployments now look like:"
    kubectl get deployments -n $NAMESPACE -o wide
}

rolloutDeployments() {
    # This function deprecated. It gets all deployments and iterates over each and changes the image name and its version.
    echo "Setting all deployment images to Version:'$VERSION' of the namespace '$NAMESPACE'"
    for deployment in $(kubectl get deploy -n $NAMESPACE -o=jsonpath='{.items..metadata.name}'); do
        echo "Rolling up deployment for ${deployment}"
        # main container images == deployment
        container=$deployment
        # TODO Rename front image to frontend
        if [ "$deployment" = "frontend" ]; then
            container="front"
        fi
        # Bumping up deployment
        kubectl -n $NAMESPACE set image deployment/$deployment $container=$REPOSITORY/$deployment:$VERSION
    done
    echo "Waiting for all pods of all deployments to be ready and running..."
    kubectl wait --for=condition=Ready --timeout=300s --all pods --namespace $NAMESPACE || true
}

resetDatabase() {
    if $RESET_DB; then
        echo "Resetting database, stateful pods will be recycled"
        kubectl delete pod -n $NAMESPACE accounts-db-0 ledger-db-0
    else
        echo "No database will be resetted"
    fi
}

applyDeploymentChange() {
    printOutput

    resetDatabase

    #envsubst <cluster/deploy.yaml | deployment-dev.yaml
    # Put in a generated file for logging.
    envsubst <deployment.yaml >gen/$YAMLFILE

    kubectl apply -f gen/$YAMLFILE
    # If we want to do an inliner
    # kubectl apply -f <( envsubst < deployment.yaml )
    echo "Waiting for all pods of all deployments to be ready and running..."
    kubectl wait --for=condition=Ready --timeout=300s --all pods --namespace $NAMESPACE || true
}

getNodes() {
    for node in $(kubectl get nodes -o name); do
        echo "     Node Name: ${node##*/}"
        echo "Type/Node Name: ${node}"
        echo
    done
}

usage() {
    echo "================================================================"
    echo "Rollout helper to Rollout images for all deployments            "
    echo "in a given namespace                                            "
    echo "                                                                "
    echo "================================================================"
    echo "Usage: bash rollout.sh [-n namespace] [-v version]              "
    echo "                                                                "
    echo "     -e      Environment. Default '$ENVIRONMENT'                "
    echo "             Namespace=Environment-App                          "
    echo "     -v      Version. Calculated '$VERSION'                     "
    echo "================================================================"
}

setDefaultValues
calculateVersion

# Read Flags
while getopts e:v:d:h: flag; do
    case "${flag}" in
    # we do another case for the stages
    e)
        case "${OPTARG}" in
        development)
            ENVIRONMENT="development"
            ;;
        staging)
            ENVIRONMENT="staging"
            ;;
        production)
            ENVIRONMENT="production"
            ;;
        *)
            echo "not a valid environment"
            exit 1
            ;;
        esac
        ;;
    v) # overwrite version from pipeline
        VERSION=${OPTARG}
        ;;
    d) # we delete/init the statefulset database
        RESET_DB=true
        ;;
    h)
        usage
        exit 0
        ;;
    *)
        usage
        exit 1
        ;;
    esac
done

exportVariables

applyDeploymentChange

printDeployments