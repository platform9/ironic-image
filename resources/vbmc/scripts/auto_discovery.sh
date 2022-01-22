#!/bin/bash

kubeconfig=`env | grep KUBECONFIG`
if [ -z $kubeconfig ]; then
    export KUBECONFIG=/etc/pf9/kube.d/kubeconfigs/admin.yaml
fi

instance_uuid=$1
rule_id=$2
ironic_username=`kubectl -n baremetal-operator-system get secret ironic-credentials-secret -o=jsonpath='{.data.username}' | base64 -d`
ironic_password=`kubectl -n baremetal-operator-system get secret ironic-credentials-secret -o=jsonpath='{.data.password}' | base64 -d`
inspector_username=`kubectl -n baremetal-operator-system get secret ironic-inspector-credentials-secret -o=jsonpath='{.data.username}' | base64 -d`
inspector_password=`kubectl -n baremetal-operator-system get secret ironic-inspector-credentials-secret -o=jsonpath='{.data.password}' | base64 -d`
ironic_ip=`kubectl -n baremetal-operator-system get service ironic-service -o=jsonpath='{.status.loadBalancer.ingress[0].ip}'`
node_uuids=`curl -s -u $ironic_username:$ironic_password https://$ironic_ip:6385/v1/nodes --insecure | jq '.nodes[] | select(.provision_state=="enroll").uuid' | tr -d '"'`
O=$IFS
IFS=$(echo -en "\n\b")
for uuid in ${node_uuids[@]}
do
    readarray -d ' ' -t strarr <<< "$uuid"
    node_uuid=`echo ${strarr[0]} | tr -d ' '`
    mac_address=`curl -s -u $ironic_username:$ironic_password https://$ironic_ip:6385/v1/nodes/$node_uuid/ports --insecure | jq .ports[].address | tr -d '"'`
    pod_name=`kubectl -n baremetal-operator-system get pods -o=jsonpath='{.items[?(@.metadata.labels.name=="baremetal-operator-vbmc")].metadata.name}'`
    node_ip=`kubectl -n baremetal-operator-system get pods -o=jsonpath='{.items[?(@.metadata.labels.name=="baremetal-operator-vbmc")].spec.nodeName}'`
    rows=`kubectl -n baremetal-operator-system exec -it $pod_name -- vbmc list -c "Domain name" -c "Port" -f value`
    O=$IFS
    IFS=$(echo -en "\r\n\b")
    for row in ${rows[@]}; do
        readarray -d ' ' -t strarr <<< "$row"
        if [ "${strarr[0]}" == "$instance_uuid" ]; then
            vbmc_port=`echo -n ${strarr[1]}`
            break
        fi
    done
    rule_username=`echo -n $(curl -s -u $inspector_username:$inspector_password https://$ironic_ip:5050/v1/rules/$rule_id --insecure | jq '.actions[] | select(.path=="driver_info/ipmi_username").value') | tr -d '"' | base64`
    rule_password=`echo -n $(curl -s -u $inspector_username:$inspector_password https://$ironic_ip:5050/v1/rules/$rule_id --insecure | jq '.actions[] | select(.path=="driver_info/ipmi_password").value') | tr -d '"' | base64`
    cat >"/root/bmh-$vbmc_port.yaml" <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: vbmc-$vbmc_port-secret
type: Opaque
data:
  username: $rule_username
  password: $rule_password
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
EOF
done
