#!/usr/bin/env bash

. ../../include/common.sh
. .envrc

debug_mode

set -Eeuo pipefail

curl -Lo klog.sh "$SCF_REPO"/raw/"$SCF_BRANCH"/container-host-files/opt/scf/bin/klog.sh
chmod +x klog.sh
mv klog.sh bin/

klog.sh
