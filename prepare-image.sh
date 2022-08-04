#!/usr/bin/bash

set -euxo pipefail

IRONIC_PKG_LIST=/tmp/ironic-${INSTALL_TYPE}-list.txt

echo "install_weak_deps=False" >> /etc/dnf/dnf.conf
# Tell RPM to skip installing documentation
echo "tsflags=nodocs" >> /etc/dnf/dnf.conf

dnf install -y python3 python3-requests 'dnf-command(config-manager)'

# RPM install #
if [[ $INSTALL_TYPE == "rpm" ]]; then
    curl https://raw.githubusercontent.com/openstack/tripleo-repos/master/plugins/module_utils/tripleo_repos/main.py | python3 - -b master current-tripleo
    # NOTE(elfosardo): enable CRB repo for more python3 dependencies
    dnf config-manager --set-enabled powertools 
    dnf upgrade -y
    xargs -rtd'\n' dnf install -y < $IRONIC_PKG_LIST
fi

# SOURCE install #
if [[ $INSTALL_TYPE == "source" ]]; then
    BUILD_DEPS="python3-devel gcc git-core"
    dnf upgrade -y
    # NOTE(dtantsur): pip is a requirement of python3 in CentOS
    dnf install -y python3-pip $BUILD_DEPS
    pip3 install pip==21.3.1
    pip3 install --prefix /usr -r $IRONIC_PKG_LIST -c https://raw.githubusercontent.com/openstack/requirements/stable/yoga/upper-constraints.txt

    # ironic and ironic-inspector system configuration
    mkdir -p /var/log/ironic /var/log/ironic-inspector /var/lib/ironic /var/lib/ironic-inspector
    getent group ironic >/dev/null || groupadd -r ironic
    getent passwd ironic >/dev/null || useradd -r -g ironic -s /sbin/nologin ironic -d /var/lib/ironic
    getent group ironic-inspector >/dev/null || groupadd -r ironic-inspector
    getent passwd ironic-inspector >/dev/null || useradd -r -g ironic-inspector -s /sbin/nologin ironic-inspector -d /var/lib/ironic-inspector

    # clean installed build dependencies
    dnf remove -y $BUILD_DEPS
fi

xargs -rtd'\n' dnf install -y < /tmp/${PKGS_LIST}

if [[ ! -z ${EXTRA_PKGS_LIST:-} ]]; then
    if [[ -s /tmp/${EXTRA_PKGS_LIST} ]]; then
        xargs -rtd'\n' dnf install -y < /tmp/${EXTRA_PKGS_LIST}
    fi
fi

dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
dnf config-manager --set-disabled epel
dnf install -y --enablerepo=epel inotify-tools

# NOTE(elfosardo): we need to reinstall tzdata as the base CS9 container removes
# its content, for more info see https://bugzilla.redhat.com/show_bug.cgi?id=2052861
dnf reinstall -y tzdata

chown ironic:ironic /var/log/ironic
# This file is generated after installing mod_ssl and it affects our configuration
rm -f /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/autoindex.conf /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.modules.d/*.conf


dnf clean all
rm -rf /var/cache/{yum,dnf}/*

# apply patches if present #
if [[ ! -z ${PATCH_LIST:-} ]]; then
    if [[ -s "/tmp/${PATCH_LIST}" ]]; then
        /bin/patch-image.sh;
    fi
fi
rm -f /bin/patch-image.sh
