#!/bin/bash

cd iac

echo "$DIGITALOCEAN_PRIVATE_KEY" > /tmp/.id_rsa

if [ -f "/tmp/.id_rsa" ]; then
  chmod og-rwx /tmp/.id_rsa
fi

export KUBECTL_CMD=`which kubectl`

if [ -z "$KUBECTL_CMD" ]; then
  KUBECTL_CMD=./kubectl
fi

export TERRAFORM_CMD=`which terraform`

if [ -z "$TERRAFORM_CMD" ]; then
  TERRAFORM_CMD=./terraform
fi

if [ ! -d "~/.terraform.d" ]; then
  mkdir -p ~/.terraform.d
fi

if [ ! -f "~/.terraform.d/credentials.tfrc.json" ]; then
  cp credentials.tfrc.json /tmp

  sed -i -e 's|${TERRAFORM_TOKEN}|'"$TERRAFORM_TOKEN"'|g' /tmp/credentials.tfrc.json

  mv /tmp/credentials.tfrc.json ~/.terraform.d
fi

$TERRAFORM_CMD init
$TERRAFORM_CMD apply -auto-approve \
                     -var "digitalocean_token=$DIGITALOCEAN_TOKEN" \
                     -var "digitalocean_public_key=$DIGITALOCEAN_PUBLIC_KEY" \
                     -var "digitalocean_private_key=$DIGITALOCEAN_PRIVATE_KEY" \
                     -var "datadog_agent_key=$DATADOG_AGENT_KEY"

export CLUSTER_MANAGER_IP=$($TERRAFORM_CMD output -raw cluster-manager-ip)

scp -i /tmp/.id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$CLUSTER_MANAGER_IP:/etc/rancher/k3s/k3s.yaml ./.kubeconfig

sed -i -e 's|127.0.0.1|'"$CLUSTER_MANAGER_IP"'|g' ./.kubeconfig

cp ./kubernetes.yml /tmp/kubernetes.yml

export BUILD_VERSION=`sed 's/BUILD_VERSION=//g' .env`

sed -i -e 's|${BUILD_VERSION}|'"$BUILD_VERSION"'|g' /tmp/kubernetes.yml

$KUBECTL_CMD --kubeconfig=./.kubeconfig apply -f /tmp/kubernetes.yml

rm -f /tmp/kubernetes.yml
rm -f ./.kubeconfig*
rm -f /tmp/.id_rsa
rm -f ./cluster-manager-ip

cd ..