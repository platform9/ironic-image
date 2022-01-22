#!/bin/bash

kubeconfig=`env | grep KUBECONFIG`
if [ -z $kubeconfig ]; then
    export KUBECONFIG=/etc/pf9/kube.d/kubeconfigs/admin.yaml
fi

for elem in "${@}"; do
    IFS="," read -a strarr <<< "$elem"
    vbmc_port=${strarr[0]}
    hypervisor_name=${strarr[1]}
    instance_id=${strarr[2]}

    if [ -z $vbmc_port ] || [ -z $hypervisor_name ] || [ -z $instance_id ]; then
        echo "Usage: $0 'vbmc_port,hypervisor_name,instance_uuid'"
        exit 1
    fi
    pod_name=`kubectl -n baremetal-operator-system get pods -o=jsonpath='{.items[?(@.metadata.labels.name=="baremetal-operator-vbmc")].metadata.name}'`
    kubectl -n baremetal-operator-system exec -it $pod_name -- vbmc add --port $vbmc_port --libvirt-uri "qemu+tls://root@$hypervisor_name/system?no_verify=1&pkipath=/etc/pf9/certs/libvirt" $instance_id
    kubectl -n baremetal-operator-system exec -it $pod_name -- vbmc start $instance_id
done
