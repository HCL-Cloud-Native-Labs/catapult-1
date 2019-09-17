#!/bin/bash
set -x

# duplicated in s/include/common.sh, needed for bootstrapping:
export CLUSTER_NAME=${CLUSTER_NAME:-kind}
export BUILD_DIR=build${CLUSTER_NAME}

mkdir "$BUILD_DIR"

. scripts/include/common.sh

cat <<HEREDOC > .envrc
export KUBECONFIG=$(pwd)/kubeconfig
export HELM_HOME=$(pwd)/.helm
export CF_HOME=$(pwd)/.cf
HEREDOC

popd