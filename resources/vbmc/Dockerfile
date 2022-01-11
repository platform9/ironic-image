ARG BASE_IMAGE=quay.io/centos/centos:stream8

FROM $BASE_IMAGE

RUN dnf install -y python3 python3-requests python3-pip && \
     curl https://raw.githubusercontent.com/openstack/tripleo-repos/master/plugins/module_utils/tripleo_repos/main.py | python3 - -b master current-tripleo && \
     dnf upgrade -y && \
     dnf install -y python3-virtualbmc && \
     dnf clean all && \
     rm -rf /var/cache/{yum,dnf}/*

COPY download-certificates.sh /bin/
CMD /bin/download-certificates.sh; /usr/bin/vbmcd --foreground
