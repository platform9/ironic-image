#!/bin/bash

kubeconfig=`env | grep KUBECONFIG`
if [ -z $kubeconfig ]; then
    export KUBECONFIG=/etc/pf9/kube.d/kubeconfigs/admin.yaml
fi

username=$1
password=$2
kernel_image=$3
ramdisk_image=$4
address=`kubectl -n baremetal-operator-system get pods -o=jsonpath='{.items[?(@.metadata.labels.name=="baremetal-operator-vbmc")].spec.nodeName}'`

if [ -z "$username" ] || [ -z "$password" ]; then
    echo "Usage: $0 [username] [password] [--optional kernel_image] [--optional ramdisk_image]"
    exit 1
fi

if [ -z "$kernel_image" ]; then
    kernel_image="https://ironic-images.s3.us-west-1.amazonaws.com/metal3/ironic-agent.kernel"
fi

if [ -z "$ramdisk_image" ]; then
    ramdisk_image="https://ironic-images.s3.us-west-1.amazonaws.com/metal3/ironic-agent.initramfs"
fi

cat >/root/inspection-rules.json <<EOL
{
  "description": "Set default IPMI credentials",
  "conditions": [
    {"op": "eq", "field": "data://auto_discovered", "value": true}
  ],
  "actions": [
    {"action": "set-attribute", "path": "driver", "value": "ipmi"},
    {"action": "set-attribute", "path": "driver_info/ipmi_address", "value": "$address"},
    {"action": "set-attribute", "path": "driver_info/ipmi_username", "value": "$username"},
    {"action": "set-attribute", "path": "driver_info/ipmi_password", "value": "$password"},
    {"action": "set-attribute", "path": "driver_info/deploy_kernel", "value": "$kernel_image"},
    {"action": "set-attribute", "path": "driver_info/deploy_ramdisk", "value": "$ramdisk_image"},
    {"action": "set-attribute", "path": "properties/capabilities", "value": "boot_option:local"},
    {"action": "set-attribute", "path": "resource_class", "value": "baremetal"}
  ]
}
EOL

username=`kubectl -n baremetal-operator-system get secret ironic-inspector-credentials-secret -o=jsonpath='{.data.username}' | base64 -d`
password=`kubectl -n baremetal-operator-system get secret ironic-inspector-credentials-secret -o=jsonpath='{.data.password}' | base64 -d`
ironic_ip=`kubectl -n baremetal-operator-system get service ironic-service -o=jsonpath='{.status.loadBalancer.ingress[0].ip}'`
curl -X POST -H "Content-Type: application/json" https://$ironic_ip:5050/v1/rules -u $username:$password -d @/root/inspection-rules.json --insecure
