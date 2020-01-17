#!/bin/bash

. ./defaults.sh
. ../../include/common.sh
. .envrc

smoke_tests_pod_name() {
  kubectl get pods --namespace "${KUBECF_NAMESPACE}" --output name 2> /dev/null | grep "smoke-tests"
}

# Wait for smoke-tests to start.
wait_for_smoke_tests_pod() {
  local timeout="300"
  until kubectl get pods --namespace "${KUBECF_NAMESPACE}" --output name 2> /dev/null | grep --quiet "smoke-tests" || [[ "$timeout" == "0" ]]; do sleep 1; timeout=$((timeout - 1)); done
  if [[ "${timeout}" == 0 ]]; then return 1; fi
  pod_name="$(smoke_tests_pod_name)"
  until [[ "$(kubectl get "${pod_name}" --namespace "${KUBECF_NAMESPACE}" --output jsonpath='{.status.containerStatuses[?(@.name == "smoke-tests-smoke-tests")].state.running}' 2> /dev/null)" != "" ]] || [[ "$(kubectl get "${pod_name}" --namespace "${KUBECF_NAMESPACE}" --output jsonpath='{.status.containerStatuses[?(@.name == "smoke-tests-smoke-tests")].state.terminated}' 2> /dev/null)" != "" ]]  || [[ "$timeout" == "0" ]]; do sleep 1; timeout=$((timeout - 1)); done
  if [[ "${timeout}" == 0 ]]; then return 1; fi
  return 0
}


pushd "$KUBECF_CHECKOUT"
    sed -i 's/namespace = "kubecf"/namespace = "'"$KUBECF_NAMESPACE"'"/' def.bzl
    sed -i 's/deployment_name = "kubecf"/deployment_name =  "'"$KUBECF_DEPLOYMENT_NAME"'"/' def.bzl
    if [ "${KUBECF_TEST_SUITE}" == "smokes" ]; then
        pod_name="$(smoke_tests_pod_name)"
        if [ -z "$pod_name" ];then
            bazel run //testing/smoke_tests
        fi
    else
        bazel run //testing/acceptance_tests
    fi
popd

if [ "${KUBECF_TEST_SUITE}" == "smokes" ]; then
    set -x
    echo "Waiting for the smoke-tests pod to start..."
    wait_for_smoke_tests_pod || {
    >&2 echo "Timed out waiting for the smoke-tests pod"
    exit 1
    }

    # Follow the logs. If the tests fail, the logs command will also fail.
    pod_name="$(smoke_tests_pod_name)"
    kubectl attach "${pod_name}" --namespace "${KUBECF_NAMESPACE}" --container smoke-tests-smoke-tests ||:

    # Wait for the container to terminate and then exit the script with the container's exit code.
    jsonpath='{.status.containerStatuses[?(@.name == "smoke-tests-smoke-tests")].state.terminated.exitCode}'
    while true; do
    exit_code="$(kubectl get "${pod_name}" --namespace "${KUBECF_NAMESPACE}" --output "jsonpath=${jsonpath}")"
    if [[ -n "${exit_code}" ]]; then
        exit "${exit_code}"
    fi
    sleep 1
    done
fi