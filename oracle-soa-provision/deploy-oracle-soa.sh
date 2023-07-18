#!/bin/sh
echo
echo "############# Provisioning Started $(date) #############"
echo 
ORACLE_WEBLOGIC_PROJECT_NAME="oracle-fusion-operator"
ORACLE_SOA_DOMAIN_PROJECT_NAME="oracle-fusion-domain"
SCRIPTS_PATH="."
OPERATOR_HELM_CHART="weblogic-operator/weblogic-operator"
OPERATOR_SA_NAME="fmw-operator-sa"
OPERATOR_IMAGE="ghcr.io/oracle/weblogic-kubernetes-operator:4.0.6"

############ Credentials Vars ################
WL_UN=weblogic
WL_PWD=Welcome1
DOMAINUID=soainfra
WL_CREDS_NAME=soainfra-domain-credentials

RCU_UN=domainuser
RCU_PWD=DomainUser123
SYSDBA_UN=sys
SYSDBA_PWD=SysPass123
RCU_CREDS_NAME=soainfra-rcu-credentials

ORA_RCU_SECRET=oracle-rcu-secret

IMAGE_PULL_UN=user@gmail.com
IMAGE_PULL_PWD=User@Password
IMAGE_PULL_EMAIL=user@gmail.com
IMAGE_PULL_CREDS_NAME=ora-image-pull
IMAGE_PULL_URL=container-registry.oracle.com/middleware/soasuite:12.2.1.4
##############################################

############### RCU Params ###################
RCU_SCHEMA_PREFIX=SOA1
RCU_SCHEMA_TYPE=soaosb
DB_CONNECTION_URL=192.168.1.1:31521/xepdb1

##############################################
echo 
# Create the namespaces for the serverless apps and DataGrid
echo "############### Creating projects: $ORACLE_WEBLOGIC_PROJECT_NAME, $ORACLE_SOA_DOMAIN_PROJECT_NAME  $(date) ############### "
oc new-project $ORACLE_WEBLOGIC_PROJECT_NAME --display-name=$ORACLE_WEBLOGIC_PROJECT_NAME --description=$ORACLE_WEBLOGIC_PROJECT_NAME
oc new-project $ORACLE_SOA_DOMAIN_PROJECT_NAME --display-name=$ORACLE_SOA_DOMAIN_PROJECT_NAME --description=$ORACLE_SOA_DOMAIN_PROJECT_NAME
oc label namespace $ORACLE_SOA_DOMAIN_PROJECT_NAME weblogic-operator=enabled

oc create serviceaccount -n $ORACLE_WEBLOGIC_PROJECT_NAME $OPERATOR_SA_NAME
oc adm policy add-scc-to-user privileged system:serviceaccount:$ORACLE_WEBLOGIC_PROJECT_NAME:$OPERATOR_SA_NAME
echo "######################### Creating projects completed ###########################"
echo
echo "############### Installing the operator  $(date) ###############"
helm install fmw-weblogic-operator $OPERATOR_HELM_CHART --namespace $ORACLE_WEBLOGIC_PROJECT_NAME --set serviceAccount=$OPERATOR_SA_NAME --set image=$OPERATOR_IMAGE --set "javaLoggingLevel=FINE" --wait
echo "########################## Operator install completed ##########################"
echo
echo "############### Creating PV and PVC  $(date) ############### "
oc apply -f ./create-pv-pvc/soainfra-domain-pvc.yaml -n $ORACLE_SOA_DOMAIN_PROJECT_NAME
echo "######################### Creating PV and PVC completed ###########################"
echo
echo "############### Creating credentials $(date) ###############"
./create-weblogic-domain-credentials/create-weblogic-credentials.sh -u $WL_UN -p $WL_PWD -n $ORACLE_SOA_DOMAIN_PROJECT_NAME -d $DOMAINUID -s $WL_CREDS_NAME
./create-rcu-credentials/create-rcu-credentials.sh -u $RCU_UN -p $RCU_PWD -a $SYSDBA_UN -q $SYSDBA_PWD -n $ORACLE_SOA_DOMAIN_PROJECT_NAME -d $DOMAINUID -s $RCU_CREDS_NAME
oc -n $ORACLE_SOA_DOMAIN_PROJECT_NAME create secret generic $ORA_RCU_SECRET --from-literal='sys_username='"$SYSDBA_UN"'' --from-literal='sys_password='"$SYSDBA_PWD"'' --from-literal='password='"$RCU_PWD"''
./create-rcu-schema/create-image-pull-secret.sh -u $IMAGE_PULL_UN -p $IMAGE_PULL_PWD -e $IMAGE_PULL_EMAIL -s $IMAGE_PULL_CREDS_NAME
echo "########################## Creating credentials completed ##########################"
echo
echo "###############  RCU - Setup Oracle DB $(date)###############"
echo
./create-rcu-schema/create-rcu-schema.sh -s $RCU_SCHEMA_PREFIX -t $RCU_SCHEMA_TYPE -d $DB_CONNECTION_URL -n $ORACLE_SOA_DOMAIN_PROJECT_NAME -c $ORA_RCU_SECRET -p $IMAGE_PULL_CREDS_NAME -i $IMAGE_PULL_URL -r SOA_PROFILE_TYPE=SMALL,HEALTHCARE_INTEGRATION=NO
echo "######################### RCU - Setup Oracle DB completed $(date) ###########################"
sleep 180
echo 
echo "###############  Creating SOA domain $(date) ###############"
echo
./create-soa-domain/domain-home-on-pv/create-domain.sh -i ./create-soa-domain/domain-home-on-pv/create-domain-inputs.yaml -o ./create-soa-domain/domain-home-on-pv/create-domain-output-script
cat ./create-soa-domain/domain-home-on-pv/create-domain-output-script/weblogic-domains/soainfra/domain.yaml | sed -e "s/soainfra-soa_cluster/soainfra-soa-cluster/g" | oc apply -f -
echo "######################### Creating SOA domain completed $(date) ###########################"
echo
echo "############# Provisioning completed $(date) #############"
