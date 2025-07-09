#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

verify_task1() {
  TASK_NUMBER="1"

  local expected_deploy_name="webapp-deploy"
  local expected_image="nginx:1.25"
  local expected_replicas=3
  local expected_port=80

  local deploy_json
  deploy_json=$(kubectl get deployment "$expected_deploy_name" -o json 2>/dev/null) || { failed; return; }

  # Check deployment name
  local deploy_name
  deploy_name=$(echo "$deploy_json" | jq -r '.metadata.name')
  [ "$deploy_name" = "$expected_deploy_name" ] || { failed; return; }

  # Check replicas
  local replicas
  replicas=$(echo "$deploy_json" | jq '.spec.replicas')
  [ "$replicas" -eq "$expected_replicas" ] || { failed; return; }

  # Check container image
  local image
  image=$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].image')
  [ "$image" = "$expected_image" ] || { failed; return; }

  # Check container port
  local port
  port=$(echo "$deploy_json" | jq '.spec.template.spec.containers[0].ports[0].containerPort')
  [ "$port" -eq "$expected_port" ] || { failed; return; }

  solved
  return
}

verify_task2() {
  TASK_NUMBER="2"
  local deployment_name="api-deploy"
  local namespace="task2"
  local expected_image="nginx:1.29"
  local expected_replicas="2"
  local expected_strategy="RollingUpdate"

  # Get deployment as JSON
  local deploy_json
  deploy_json="$(kubectl get deployment "${deployment_name}" -n "${namespace}" -o json)" || { failed; return; }

  # Check replicas
  local replicas
  replicas="$(echo "${deploy_json}" | jq -r '.spec.replicas')" || { failed; return; }
  [ "${replicas}" = "${expected_replicas}" ] || { failed; return; }

  # Check image
  local image
  image="$(echo "${deploy_json}" | jq -r '.spec.template.spec.containers[0].image')" || { failed; return; }
  [ "${image}" = "${expected_image}" ] || { failed; return; }

  # Check strategy is RollingUpdate (for zero downtime)
  local strategy
  strategy="$(echo "${deploy_json}" | jq -r '.spec.strategy.type')" || { failed; return; }
  [ "${strategy}" = "${expected_strategy}" ] || { failed; return; }

  # Check that all pods are running and ready with the correct image
  local ready_replicas
  ready_replicas="$(echo "${deploy_json}" | jq -r '.status.readyReplicas')" || { failed; return; }
  [ "${ready_replicas}" = "${expected_replicas}" ] || { failed; return; }

  local updated_replicas
  updated_replicas="$(echo "${deploy_json}" | jq -r '.status.updatedReplicas')" || { failed; return; }
  [ "${updated_replicas}" = "${expected_replicas}" ] || { failed; return; }

  solved
  return
}

verify_task3() {
  TASK_NUMBER="3"

  local deployment_name="cache-deploy"
  local expected_image="redis:8.0.2"
  local expected_replicas=4
  local deploy_json

  deploy_json="$(kubectl get deployment ${deployment_name} -o json)" || { failed; return; }

  # Check number of replicas
  local replicas
  replicas="$(echo "${deploy_json}" | jq '.spec.replicas')" || { failed; return; }
  [ "${replicas}" -eq "${expected_replicas}" ] || { failed; return; }

  # Check image of all containers in the deployment
  local image
  image="$(echo "${deploy_json}" | jq -r '.spec.template.spec.containers[0].image')" || { failed; return; }
  [ "${image}" = "${expected_image}" ] || { failed; return; }

  solved
  return
}

verify_task4() {
  TASK_NUMBER="4"

  local deploy_name="worker-deploy"
  local expected_replicas_up=5
  local expected_replicas_down=2
  local deploy_json replicas events_json scaled_up scaled_down

  # Get deployment as JSON (only once)
  deploy_json="$(kubectl get deployment "${deploy_name}" -o json)" || { failed; return; }

  # Check if deployment exists and is currently scaled to 2
  replicas="$(echo "${deploy_json}" | jq '.spec.replicas')" || { failed; return; }
  if [ "${replicas}" -ne "${expected_replicas_down}" ]; then
    failed
    return
  fi

  # Get events for the deployment (only once)
  events_json="$(kubectl get event --field-selector involvedObject.kind=Deployment,involvedObject.name=${deploy_name} -o json)" || { failed; return; }

  # Check for scale up event to 5
  scaled_up="$(echo "${events_json}" | jq -r --arg up_msg "Scaled up replica set" --argjson up_replicas "${expected_replicas_up}" \
    '.items[] | select(.message | test($up_msg)) | select(.message | test("to " + ($up_replicas|tostring))) | .message' | wc -l)"
  if [ "${scaled_up}" -eq 0 ]; then
    failed
    return
  fi

  # Check for scale down event to 2
  scaled_down="$(echo "${events_json}" | jq -r --arg down_msg "Scaled down replica set" --argjson down_replicas "${expected_replicas_down}" \
    '.items[] | select(.message | test($down_msg)) | select(.message | test("to " + ($down_replicas|tostring))) | .message' | wc -l)"
  if [ "${scaled_down}" -eq 0 ]; then
    failed
    return
  fi

  solved
  return
}

verify_task5() {
  TASK_NUMBER="5"

  local deploy_name="analytics-deploy"
  local expected_image="python:3.12"
  local expected_command='["python","-c","import time; time.sleep(99999999)"]'
  local expected_cpu_req="100m"
  local expected_cpu_lim="500m"
  local expected_mem_req="128Mi"
  local expected_mem_lim="512Mi"
  local expected_replicas="1"
  local expected_mem_req expected_mem_lim expected_replicas deploy_json


  deploy_json="$(kubectl get deployment ${deploy_name} -o json)" || { failed; return; }

  # Check replicas
  local replicas
  replicas="$(echo "$deploy_json" | jq -r '.spec.replicas')" || { failed; return; }
  [ "$replicas" = "$expected_replicas" ] || { failed; return; }

  # Check image
  local image
  image="$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].image')" || { failed; return; }
  [ "$image" = "$expected_image" ] || { failed; return; }

  # Check command
  local command
  command="$(echo "$deploy_json" | jq -c '.spec.template.spec.containers[0].command')" || { failed; return; }
  [ "$command" = "$expected_command" ] || { failed; return; }

  # Check CPU request
  local cpu_req
  cpu_req="$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].resources.requests.cpu')" || { failed; return; }
  [ "$cpu_req" = "$expected_cpu_req" ] || { failed; return; }

  # Check CPU limit
  local cpu_lim
  cpu_lim="$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].resources.limits.cpu')" || { failed; return; }
  [ "$cpu_lim" = "$expected_cpu_lim" ] || { failed; return; }

  # Check memory request
  local mem_req
  mem_req="$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].resources.requests.memory')" || { failed; return; }
  [ "$mem_req" = "$expected_mem_req" ] || { failed; return; }

  # Check memory limit
  local mem_lim
  mem_lim="$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].resources.limits.memory')" || { failed; return; }
  [ "$mem_lim" = "$expected_mem_lim" ] || { failed; return; }

  solved
  return
}

verify_task6() {
  TASK_NUMBER="6"

  local deploy_name="envtest-deploy"
  local expected_image="nginx:1.29"
  local expected_replicas=2
  local expected_env0_name="ENV"
  local expected_env0_value="production"
  local expected_env1_name="DEBUG"
  local expected_env1_value="false"

  local deploy_json
  deploy_json="$(kubectl get deployment ${deploy_name} -o json)" || { failed; return; }

  # Check deployment name
  local name
  name="$(echo "${deploy_json}" | jq -r '.metadata.name')" || { failed; return; }
  [ "${name}" = "${deploy_name}" ] || { failed; return; }

  # Check replicas
  local replicas
  replicas="$(echo "${deploy_json}" | jq '.spec.replicas')" || { failed; return; }
  [ "${replicas}" -eq "${expected_replicas}" ] || { failed; return; }

  # Check container image
  local image
  image="$(echo "${deploy_json}" | jq -r '.spec.template.spec.containers[0].image')" || { failed; return; }
  [ "${image}" = "${expected_image}" ] || { failed; return; }

  # Check environment variables
  local env_count
  env_count="$(echo "${deploy_json}" | jq '.spec.template.spec.containers[0].env | length')" || { failed; return; }
  [ "${env_count}" -ge 2 ] || { failed; return; }

  local env0_name env0_value env1_name env1_value
  env0_name="$(echo "${deploy_json}" | jq -r '.spec.template.spec.containers[0].env[0].name')" || { failed; return; }
  env0_value="$(echo "${deploy_json}" | jq -r '.spec.template.spec.containers[0].env[0].value')" || { failed; return; }
  env1_name="$(echo "${deploy_json}" | jq -r '.spec.template.spec.containers[0].env[1].name')" || { failed; return; }
  env1_value="$(echo "${deploy_json}" | jq -r '.spec.template.spec.containers[0].env[1].value')" || { failed; return; }

  [ "${env0_name}" = "${expected_env0_name}" ] || { failed; return; }
  [ "${env0_value}" = "${expected_env0_value}" ] || { failed; return; }
  [ "${env1_name}" = "${expected_env1_name}" ] || { failed; return; }
  [ "${env1_value}" = "${expected_env1_value}" ] || { failed; return; }

  solved
  return
}

verify_task7() {
  TASK_NUMBER="7"

  local configmap_name="app-config"
  local configmap_key="APP_MODE"
  local configmap_value="debug"
  local deployment_name="configmap-deploy"
  local expected_image="nginx:1.29.0"
  local expected_replicas="1"

  # Get ConfigMap as JSON
  local configmap_json
  configmap_json="$(kubectl get configmap ${configmap_name} -o json)" || { failed; return; }

  # Verify ConfigMap key and value
  local actual_value
  actual_value="$(echo "${configmap_json}" | jq -r ".data.${configmap_key}")" || { failed; return; }
  [ "${actual_value}" = "${configmap_value}" ] || { failed; return; }

  # Get Deployment as JSON
  local deploy_json
  deploy_json="$(kubectl get deployment ${deployment_name} -o json)" || { failed; return; }

  # Verify replicas
  local actual_replicas
  actual_replicas="$(echo "${deploy_json}" | jq -r ".spec.replicas")" || { failed; return; }
  [ "${actual_replicas}" = "${expected_replicas}" ] || { failed; return; }

  # Verify image
  local actual_image
  actual_image="$(echo "${deploy_json}" | jq -r '.spec.template.spec.containers[0].image')" || { failed; return; }
  [ "${actual_image}" = "${expected_image}" ] || { failed; return; }

  # Verify env from ConfigMap
  local envfrom_configmap
  envfrom_configmap="$(echo "${deploy_json}" | jq -r '.spec.template.spec.containers[0].envFrom[]? | select(.configMapRef.name=="'${configmap_name}'") | .configMapRef.name')" || { failed; return; }
  [ "${envfrom_configmap}" = "${configmap_name}" ] || { failed; return; }

  solved
  return
}

verify_task8() {
  TASK_NUMBER="8"

  local secret_name="db-secret"
  local secret_key="DB_PASSWORD"
  local secret_value="supersecret"
  local deploy_name="secret-deploy"
  local image_name="mysql:8.4"
  local env_name="MYSQL_ROOT_PASSWORD"
  local replicas="1"
  local secret_json deploy_json found value

  secret_json="$(kubectl get secret ${secret_name} -o json)" || { failed; return; }
  found="$(echo "$secret_json" | jq -r ".data | has(\"${secret_key}\")")"
  [ "$found" = "true" ] || { failed; return; }
  value="$(echo "$secret_json" | jq -r ".data[\"${secret_key}\"]" | base64 -d)" || { failed; return; }
  [ "$value" = "$secret_value" ] || { failed; return; }

  deploy_json="$(kubectl get deployment ${deploy_name} -o json)" || { failed; return; }
  found="$(echo "$deploy_json" | jq -r ".spec.replicas")"
  [ "$found" = "$replicas" ] || { failed; return; }
  found="$(echo "$deploy_json" | jq -r ".spec.template.spec.containers[0].image")"
  [ "$found" = "$image_name" ] || { failed; return; }
  found="$(echo "$deploy_json" | jq -r ".spec.template.spec.containers[0].env[] | select(.name==\"${env_name}\") | .valueFrom.secretKeyRef.name")"
  [ "$found" = "$secret_name" ] || { failed; return; }
  found="$(echo "$deploy_json" | jq -r ".spec.template.spec.containers[0].env[] | select(.name==\"${env_name}\") | .valueFrom.secretKeyRef.key")"
  [ "$found" = "$secret_key" ] || { failed; return; }

  solved
  return
}

verify_task9() {
  TASK_NUMBER="9"

  local deploy_name="probe-deploy"
  local expected_image="httpd:2.4"
  local expected_replicas=2
  local expected_probe_path="/"
  local expected_probe_port=80

  local deploy_json
  deploy_json="$(kubectl get deployment ${deploy_name} -o json)" || { failed; return; }

  # Check deployment name
  local name
  name="$(echo "$deploy_json" | jq -r '.metadata.name')" || { failed; return; }
  [ "$name" = "$deploy_name" ] || { failed; return; }

  # Check replicas
  local replicas
  replicas="$(echo "$deploy_json" | jq '.spec.replicas')" || { failed; return; }
  [ "$replicas" -eq "$expected_replicas" ] || { failed; return; }

  # Check container image
  local image
  image="$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].image')" || { failed; return; }
  [ "$image" = "$expected_image" ] || { failed; return; }

  # Check readiness probe path and port
  local probe_path
  probe_path="$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].readinessProbe.httpGet.path')" || { failed; return; }
  [ "$probe_path" = "$expected_probe_path" ] || { failed; return; }

  local probe_port
  probe_port="$(echo "$deploy_json" | jq '.spec.template.spec.containers[0].readinessProbe.httpGet.port')" || { failed; return; }
  [ "$probe_port" -eq "$expected_probe_port" ] || { failed; return; }

  solved
  return
}

verify_task10() {
  TASK_NUMBER="10"

  local deployment_name="liveness-deploy"
  local expected_image="redis:7.2"
  local expected_replicas=1
  local expected_probe_command='["redis-cli","ping"]'
  local expected_probe_period=11

  local deploy_json
  deploy_json="$(kubectl get deployment ${deployment_name} -o json)" || { failed; return; }

  # Check deployment name
  local name
  name="$(echo "$deploy_json" | jq -r '.metadata.name')" || { failed; return; }
  [[ "$name" == "$deployment_name" ]] || { failed; return; }

  # Check replicas
  local replicas
  replicas="$(echo "$deploy_json" | jq '.spec.replicas')" || { failed; return; }
  [[ "$replicas" -eq "$expected_replicas" ]] || { failed; return; }

  # Check container image
  local image
  image="$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].image')" || { failed; return; }
  [[ "$image" == "$expected_image" ]] || { failed; return; }

  # Check liveness probe exists
  local liveness_probe
  liveness_probe="$(echo "$deploy_json" | jq '.spec.template.spec.containers[0].livenessProbe')" || { failed; return; }
  [[ "$liveness_probe" != "null" ]] || { failed; return; }

  # Check liveness probe command
  local probe_command
  probe_command="$(echo "$deploy_json" | jq -c '.spec.template.spec.containers[0].livenessProbe.exec.command')" || { failed; return; }
  [[ "$probe_command" == "$expected_probe_command" ]] || { failed; return; }

  # Check liveness probe periodSeconds
  local probe_period
  probe_period="$(echo "$deploy_json" | jq '.spec.template.spec.containers[0].livenessProbe.periodSeconds')" || { failed; return; }
  [[ "$probe_period" -eq "$expected_probe_period" ]] || { failed; return; }

  solved
  return
}

verify_task11() {
  TASK_NUMBER="11"

  local deployment_name="label-deploy"
  local expected_image="nginx:1.25"
  local expected_label_key="tier"
  local expected_label_value="backend"
  local expected_replicas=3
  local deployment_json pod_template_labels selector_match_labels replicas image

  deployment_json="$(kubectl get deployment ${deployment_name} -o json)" || { failed; return; }

  # Check replicas
  replicas="$(echo "${deployment_json}" | jq '.spec.replicas')" || { failed; return; }
  [ "${replicas}" -eq "${expected_replicas}" ] || { failed; return; }

  # Check selector
  selector_match_labels="$(echo "${deployment_json}" | jq -r '.spec.selector.matchLabels')" || { failed; return; }
  echo "${selector_match_labels}" | jq -e "select(.${expected_label_key} == \"${expected_label_value}\")" > /dev/null || { failed; return; }

  # Check pod template labels
  pod_template_labels="$(echo "${deployment_json}" | jq -r '.spec.template.metadata.labels')" || { failed; return; }
  echo "${pod_template_labels}" | jq -e "select(.${expected_label_key} == \"${expected_label_value}\")" > /dev/null || { failed; return; }

  # Check container image
  image="$(echo "${deployment_json}" | jq -r '.spec.template.spec.containers[0].image')" || { failed; return; }
  [ "${image}" = "${expected_image}" ] || { failed; return; }

  solved
  return
}

verify_task12() {
  TASK_NUMBER="12"

  local deployment_name="recreate-deploy"
  local namespace="recreate"
  local expected_image="mongo:7.0"
  local expected_strategy="Recreate"
  local expected_replicas=4

  local deployment_json
  deployment_json="$(kubectl get deployment ${deployment_name} -n ${namespace} -o json)" || { failed; return; }

  # Check image
  local image
  image="$(echo "${deployment_json}" | jq -r '.spec.template.spec.containers[0].image')" || { failed; return; }
  [ "${image}" = "${expected_image}" ] || { failed; return; }

  # Check strategy
  local strategy
  strategy="$(echo "${deployment_json}" | jq -r '.spec.strategy.type')" || { failed; return; }
  [ "${strategy}" = "${expected_strategy}" ] || { failed; return; }

  # Check replicas
  local replicas
  replicas="$(echo "${deployment_json}" | jq -r '.spec.replicas')" || { failed; return; }
  [ "${replicas}" -eq "${expected_replicas}" ] || { failed; return; }

  solved
  return
}

verify_task13() {
  TASK_NUMBER="13"
  local deployment_name expected_image expected_env_name expected_env_value deploy_json pod_name pod_json

  deployment_name="pause-deploy"
  expected_image="httpd:2.4"
  expected_env_name="TEST"
  expected_env_value="true"

  # Get deployment as JSON
  deploy_json="$(kubectl get deployment "${deployment_name}" -o json)" || { failed; return; }

  # 1. Verify deployment exists and has correct image
  echo "${deploy_json}" | jq -e --arg img "${expected_image}" \
    '.spec.template.spec.containers[] | select(.image == $img)' > /dev/null || { failed; return; }

  # 2. Verify deployment is paused
  echo "${deploy_json}" | jq -e '.spec.paused == true' > /dev/null || { failed; return; }

  # 3. Verify the environment variable is set in the deployment spec
  echo "${deploy_json}" | jq -e --arg name "${expected_env_name}" --arg value "${expected_env_value}" \
    '.spec.template.spec.containers[].env[]? | select(.name == $name and .value == $value)' > /dev/null || { failed; return; }

  # 4. Get the name of a pod belonging to the deployment
  pod_name="$(kubectl get pods -l app="${deployment_name}" -o json | jq -r '.items[0].metadata.name')" || { failed; return; }

  # 5. Get the pod as JSON
  pod_json="$(kubectl get pod "${pod_name}" -o json)" || { failed; return; }

  # 6. Verify the pod does NOT have the environment variable set
  echo "${pod_json}" | jq -e --arg name "${expected_env_name}" \
    '[ .spec.containers[].env[]? | select(.name == $name) ] | length == 0' > /dev/null || { failed; return; }

  solved
}

verify_task14() {
  TASK_NUMBER="14"

  local deployment_name="history-deploy"
  local expected_image="nginx:1.25"
  local expected_revision_limit=2
  local expected_replicas=2

  local deploy_json
  deploy_json="$(kubectl get deployment "${deployment_name}" -o json)" || { failed; return; }

  # Check image
  local image
  image="$(echo "${deploy_json}" | jq -r '.spec.template.spec.containers[0].image')" || { failed; return; }
  [ "${image}" = "${expected_image}" ] || { failed; return; }

  # Check revision history limit
  local revision_limit
  revision_limit="$(echo "${deploy_json}" | jq -r '.spec.revisionHistoryLimit')" || { failed; return; }
  [ "${revision_limit}" = "${expected_revision_limit}" ] || { failed; return; }

  # Check replicas
  local replicas
  replicas="$(echo "${deploy_json}" | jq -r '.spec.replicas')" || { failed; return; }
  [ "${replicas}" = "${expected_replicas}" ] || { failed; return; }

  solved
  return
}

verify_task15() {
  TASK_NUMBER="15"

  local deployment_name="init-deploy"
  local expected_main_image="httpd:2.4"
  local expected_init_image="busybox:1.36"
  local expected_init_command="echo Init done"
  local expected_replicas=1
  local deployment_json main_image init_image init_command replicas

  deployment_json="$(kubectl get deployment "${deployment_name}" -o json)" || { failed; return; }

  replicas="$(echo "${deployment_json}" | jq '.spec.replicas')" || { failed; return; }
  [ "${replicas}" -eq "${expected_replicas}" ] || { failed; return; }

  main_image="$(echo "${deployment_json}" | jq -r '.spec.template.spec.containers[0].image')" || { failed; return; }
  [ "${main_image}" = "${expected_main_image}" ] || { failed; return; }

  init_image="$(echo "${deployment_json}" | jq -r '.spec.template.spec.initContainers[0].image')" || { failed; return; }
  [ "${init_image}" = "${expected_init_image}" ] || { failed; return; }

  init_command="$(echo "${deployment_json}" | jq -r '.spec.template.spec.initContainers[0].command | join(" ")')" || { failed; return; }
  case "${init_command}" in
    *"${expected_init_command}") ;;
    *) failed; return ;;
  esac

  solved
  return
}

verify_task16() {
  TASK_NUMBER="16"

  local deployment_name="affinity-deploy"
  local expected_image="nginx:1.25"
  local expected_label_key="disktype"
  local expected_label_value="ssd"
  local expected_replicas=2
  local deployment_json node_affinity_json replicas image node_affinity

  deployment_json="$(kubectl get deployment ${deployment_name} -o json)" || { failed; return; }

  replicas="$(echo "${deployment_json}" | jq '.spec.replicas')" || { failed; return; }
  [ "${replicas}" -eq "${expected_replicas}" ] || { failed; return; }

  image="$(echo "${deployment_json}" | jq -r '.spec.template.spec.containers[0].image')" || { failed; return; }
  [ "${image}" = "${expected_image}" ] || { failed; return; }

  node_affinity_json="$(echo "${deployment_json}" | jq '.spec.template.spec.affinity.nodeAffinity')" || { failed; return; }
  # Check requiredDuringSchedulingIgnoredDuringExecution exists
  echo "${node_affinity_json}" | jq '.requiredDuringSchedulingIgnoredDuringExecution' | grep -qv null || { failed; return; }
  # Check for the correct label selector
  node_affinity="$(echo "${node_affinity_json}" | jq -r '.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[] | select(.key=="'${expected_label_key}'" and .operator=="In") | .values[]')" || { failed; return; }
  [ "${node_affinity}" = "${expected_label_value}" ] || { failed; return; }

  solved
}


verify_task1
verify_task2
verify_task3
verify_task4
verify_task5
verify_task6
verify_task7
verify_task8
verify_task9
verify_task10
verify_task11
verify_task12
verify_task13
verify_task14
verify_task15
verify_task16
exit 0
