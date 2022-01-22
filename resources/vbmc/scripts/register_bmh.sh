#!/bin/bash

kubeconfig=`env | grep KUBECONFIG`
if [ -z $kubeconfig ]; then
    export KUBECONFIG=/etc/pf9/kube.d/kubeconfigs/admin.yaml
fi

for elem in "${@}"; do
    IFS="," read -a strarr <<< "$elem"
    vbmc_port=${strarr[0]}
    mac_address=${strarr[1]}
    if [ -z $vbmc_port ] || [ -z $mac_address ]; then
        echo "Usage: $0 'vbmc_port,mac_address'"
        exit 1
    fi
    node_ip=`kubectl -n baremetal-operator-system get pods -o=jsonpath='{.items[?(@.metadata.labels.name=="baremetal-operator-vbmc")].spec.nodeName}'`
    cat >/root/bmh-$vbmc_port.yaml <<EOL
---
apiVersion: v1
kind: Secret
metadata:
  name: vbmc-$vbmc_port-secret
type: Opaque
data:
  username: YWRtaW4=
  password: cGFzc3dvcmQ=
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: vbmc-$vbmc_port
spec:
  online: true
  bootMode: legacy
  bootMACAddress: $mac_address
  bmc:
    address: ipmi://$node_ip:$vbmc_port
    credentialsName: vbmc-$vbmc_port-secret
  image:
    url: https://ironic-images.s3.us-west-1.amazonaws.com/user_images/cirros-0.3.2-ssh-x86_64-disk.img
    checksum: 31f6faeebd853303f319cca6446bad63
  rootDeviceHints:
    deviceName: /dev/vda
EOL
    kubectl create -f /root/bmh-$vbmc_port.yaml
done
