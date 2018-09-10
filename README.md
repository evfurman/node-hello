Node Hello is a fun little exercise in automating the deployment of a Node.js webapp with an nginx reverse proxy using EKS and Helm.

*DEPENDENCIES:*

- [kubectl](https://docs.aws.amazon.com/eks/latest/userguide/configure-kubectl.html)  
- [aws-iam-authenticator](https://docs.aws.amazon.com/eks/latest/userguide/configure-kubectl.html)  
- [helm](https://github.com/helm/helm/blob/master/docs/install.md)  
- [docker-for-mac](https://store.docker.com/editions/community/docker-ce-desktop-mac)  

## Local Development

1.) Intialize Helm

`helm init`  

2.) Deploy the Helm Chart

`cd node-hello && helm install -f values/development-values.yaml .`  

3.) Test

`curl localhost:30000`  

## Staging/Production

1.) Deploy the Cloudformation template

`cd cfn && ./deploy.sh`  

2.) Provision the Cluster

`export KUBECONFIG=~/kubeconfig-node-hello`  
`kubectl apply -f ~/node-hello-aws-auth-cm.yaml`  

3.) Wait for Nodes to be Ready

`kubectl get nodes --watch`  

NOTE: If you don't see nodes registering, try killing the running instances. The AutoScale group will replace them and the new ones should join the cluster immediately.

4.) Initialize Helm

`helm init`  

5.) Patch Tiller for RBAC

`kubectl create serviceaccount --namespace kube-system tiller`  
`kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller`  
`kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'`  

6.) Deploy Ingress Controller

`helm install stable/nginx-ingress --name nginx-ingress --set rbac.create=true`  

7.) Deploy the Helm Chart

`cd node-hello && helm install -f values/production-values.yaml .`  
`cd node-hello && helm install -f values/staging-values.yaml --namespace=staging .`  

8.) Test

`curl --header 'Host: node-hello.com' $(kubectl get svc nginx-ingress-controller -n default -o jsonpath="{.status.loadBalancer.ingress[*].hostname}")`  

`curl --header 'Host: staging.node-hello.com' $(kubectl get svc nginx-ingress-controller -n default -o jsonpath="{.status.loadBalancer.ingress[*].hostname}")`  

## Logging

Cluster-level logs can be access via the `kubectl logs -f {POD_NAME}` command. The official nginx image creates a symbolic link from /var/log/nginx/access.log to /dev/stdout , and creates another symbolic link from /var/log/nginx/error.log to /dev/stderr , overwriting the log files and causing logs to be sent to the relevant special device instead. 

## To Do

* [Logs to Cloudwatch Using Fluentd](https://github.com/helm/charts/tree/master/incubator/fluentd-cloudwatch)
* Pipeline w/ Gitlab-CI
* Move Nodes to Spotinst
* ALB Ingress Controller?
* ExternalDNS?
