#!/bin/bash

# title: deploy.sh
# description: Deploy Script for EKS Cluster, NodeGroup and Network
# author: evfurman@gmail.com

# Define Params

STACK_NAME=eks-node-hello
CHANGE_SET=x$(openssl rand -base64 8 |md5 |head -c40;echo)

# Check whether stack exists

aws cloudformation describe-stacks \
--region us-west-2 \
--stack-name $STACK_NAME &>/dev/null
STACKEXISTSCODE=$?

if [[ $STACKEXISTSCODE -eq 255 ]]

then

# Create new stack

        echo " "
        echo "--"
        echo "Building New Infrastructure"
        echo "--"
        echo " "

	aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://./vpc_eks_nodegroup.yaml \
        --capabilities CAPABILITY_NAMED_IAM

# Wait for stack to exist	

	aws cloudformation wait stack-exists \
        --stack-name $STACK_NAME

# List current stack events	

	echo # empty echo for spacing

	aws cloudformation describe-stack-events \
        --stack-name $STACK_NAME \
        --query 'StackEvents[].[ResourceType,ResourceStatus]' \
        --output text

# Notice to pipeline

        echo " "
        echo "--"
        echo "Stack creation will take roughly 10min, get a cup of coffee in the meantime :D"
        echo "--"
        echo " "

# Wait for stack creation to complete

	aws cloudformation wait stack-create-complete \
        --stack-name $STACK_NAME

# Enable termination protection

	aws cloudformation update-termination-protection \
        --stack-name $STACK_NAME \
        --enable-termination-protection

else

# Create change set

	echo " "
        echo "--"
        echo "Checking for Infrastructure Changes"
        echo "--"
        echo " "

	aws cloudformation create-change-set \
        --stack-name $STACK_NAME \
        --change-set-name $CHANGE_SET \
        --template-body file://./vpc_eks_nodegroup.yaml \
        --capabilities CAPABILITY_NAMED_IAM \
        --change-set-type UPDATE

# Wait for change set creation to complete // Check if updates exist

	aws cloudformation wait change-set-create-complete \
        --stack-name $STACK_NAME \
        --change-set-name $CHANGE_SET &>/dev/null
	CHANGESETCODE=$?

	if [[ ! $CHANGESETCODE -eq 255 ]]

	then

# Execute change set

		echo " "
                echo "--"
                echo "Executing Infrastructure Changes"
                echo "--"
                echo " "

		aws cloudformation execute-change-set \
                --stack-name $STACK_NAME \
                --change-set-name $CHANGE_SET

# Wait for change set execution to complete

		aws cloudformation wait stack-update-complete \
                --stack-name $STACK_NAME

	else

# Delete failed change set

		echo " "
		echo "--"
		echo "No Updates Exist"
		echo "--"
		echo " "

		aws cloudformation delete-change-set \
                --stack-name $STACK_NAME \
                --change-set-name $CHANGE_SET

	fi

fi	

# Create kubeconfig

export EKS_CA=`aws cloudformation describe-stacks --stack-name $STACK_NAME |jq -r '.Stacks[].Outputs[]|select(.OutputKey=="EKSca")|.OutputValue'`
export EKS_ENDPOINT=`aws cloudformation describe-stacks --stack-name $STACK_NAME |jq -r '.Stacks[].Outputs[]|select(.OutputKey=="EKSendpoint")|.OutputValue'`
export NODE_ROLE=`aws cloudformation describe-stacks --stack-name $STACK_NAME |jq -r '.Stacks[].Outputs[]|select(.OutputKey=="NodeInstanceRole")|.OutputValue'`

/bin/cat <<EOM >~/kubeconfig-node-hello
apiVersion: v1
clusters:
- cluster:
    server: $EKS_ENDPOINT
    certificate-authority-data: $EKS_CA
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: heptio-authenticator-aws
      args:
        - "token"
        - "-i"
        - "$STACK_NAME"
EOM

/bin/cat <<EOM >~/node-hello-aws-auth-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: $NODE_ROLE
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOM
