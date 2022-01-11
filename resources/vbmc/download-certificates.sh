mkdir -p /etc/pf9/certs/libvirt/
cd /etc/pf9/certs/libvirt/
curl https://artifactory.platform9.horse/artifactory/pf9-bins/ironic/df-us-mpt1-kvm/certs/v2/ca/cert.pem -o cacert.pem
curl https://artifactory.platform9.horse/artifactory/pf9-bins/ironic/df-us-mpt1-kvm/certs/v2/hostagent/cert.pem -o clientcert.pem
curl https://artifactory.platform9.horse/artifactory/pf9-bins/ironic/df-us-mpt1-kvm/certs/v2/hostagent/key.pem -o clientkey.pem 
