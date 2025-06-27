#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

verify_task1() {
  TASK_NUMBER="1"
  local namespace="task1"
  local pod_name="nginx"

  # Check if the pod is running
  local status_phase
  status_phase=$(kubectl get pods "$pod_name" -o jsonpath="{.status.phase}" -n "$namespace" 2>/dev/null)
  if [ "$status_phase" != "Running" ]; then
    failed
    return
  fi

  # Check the image of the container
  local image
  image=$(kubectl get pods "$pod_name" -o jsonpath="{.spec.containers[0].image}" -n "$namespace" 2>/dev/null)
  if [ "$image" != "nginx:1.21" ]; then
    failed
    return
  fi

  solved
  return
}

verify_task2() {
  TASK_NUMBER="2"
  local namespace="task2"
  local pod_name="nginx"
  local image="nginx:1.21"
  local label_key="exposed"
  local label_value="true"
  local port=80
  local service_name="nginx"

  # Check if the Pod exists
  if ! kubectl get pod "$pod_name" -n "$namespace" &>/dev/null; then
    failed
    return
  fi

  # Check the Pod status (should be "Running")
  local pod_status
  pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}')
  if [[ "$pod_status" != "Running" ]]; then
    failed
    return
  fi

  # Check the image of the container
  local pod_image
  pod_image=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.containers[0].image}')
  if [[ "$pod_image" != "$image" ]]; then
    failed
    return
  fi

  # Check if the Pod has the correct label
  local pod_label
  pod_label=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath="{.metadata.labels.$label_key}")
  if [[ "$pod_label" != "$label_value" ]]; then
    failed
    return
  fi

  # Check if the Pod exposes the correct container port
  local container_port
  container_port=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.containers[0].ports[0].containerPort}')
  if [[ "$container_port" != "$port" ]]; then
    failed
    return
  fi

  # Check if the Service exists
  if ! kubectl get svc "$service_name" -n "$namespace" &>/dev/null; then
    failed
    return
  fi

  # Check if the Service targets the correct Pod by the same name (selector)
  local service_selector
  service_selector=$(kubectl get svc "$service_name" -n "$namespace" -o jsonpath='{.spec.selector.exposed}')
  if [[ "$service_selector" != "$label_value" ]]; then
    failed
    return
  fi

  # Check if the Service exposes the correct port
  local service_port
  service_port=$(kubectl get svc "$service_name" -n "$namespace" -o jsonpath='{.spec.ports[0].port}')
  if [[ "$service_port" != "$port" ]]; then
    failed
    return
  fi

  solved
  return
}

verify_task3() {
  TASK_NUMBER="3"
  local file="busybox-env.txt"

  # Check the container image, the pod name and the automatic removal of the pod
  if kubectl get events -n default 2>/dev/null | grep -q 'pod/busybox' && \
     kubectl get events -n default 2>/dev/null | grep -q 'image "busybox:1.37.0"' && \
     [[ "$(tail -1 < "${file}" 2>/dev/null)" == 'pod "busybox" deleted' ]]; then
    solved
  else
    failed
  fi
}

verify_task4() {
  TASK_NUMBER="4"

  local result
  result=$(kubectl apply -f "$(git rev-parse --show-toplevel)/.templates/b_pods/task4/pod.yaml" --dry-run=server 2> /dev/null)
  if  echo "$result" | grep -qi unchanged; then
    solved
  else
    failed
  fi
}

verify_task5() {
  TASK_NUMBER="5"
  local pod_name="task5-app"
  local container_name="busybox"
  local image_name="busybox"
  local config_map_name="app-config"
  local restart_policy="Always"
  local command='["/bin/sh","-c","sleep 7200"]'

  # Check the container name
  local container_name_found
  container_name_found=$(kubectl get pod "$pod_name" -o jsonpath='{.spec.containers[0].name}' 2>/dev/null)
  if [ "$container_name_found" != "$container_name" ]; then
    failed
    return
  fi

  # Check the container image
  container_image=$(kubectl get pod "$pod_name" -o jsonpath='{.spec.containers[0].image}')
  if [ "$container_image" != "$image_name" ]; then
    failed
    return
  fi

  # Verify the environment variables are loaded from the ConfigMap
  env_source=$(kubectl get pod "$pod_name" -o jsonpath='{.spec.containers[0].envFrom[0].configMapRef.name}')
  if [ "$env_source" != "$config_map_name" ]; then
    failed
    return
  fi

  # Verify the restart policy
  policy=$(kubectl get pod "$pod_name" -o jsonpath='{.spec.restartPolicy}')
  if [ "$policy" != "$restart_policy" ]; then
    failed
    return
  fi

  # Verify the command
  cmd=$(kubectl get pod "$pod_name" -o jsonpath='{.spec.containers[0].command}')
  if [[ "$cmd" != "$command" ]]; then
    failed
    return
  fi

  solved
  return
}

verify_task6() {
  TASK_NUMBER="6"
  local namespace="task6"
  local pod_name="nginx-init"
  local init_container="busy-init"
  local main_container="nginx"
  local init_image="busybox:1.37.0"
  local main_image="nginx:1.21"
  local shared_volume="shared"
  local expected_text="hello ckad"

  # Check if pod exists in the namespace
  if ! kubectl get pod "$pod_name" -n "$namespace" &>/dev/null; then
    failed
    return
  fi

  # Check if init container exists with the correct image
  local init_image_found
  init_image_found=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath="{.spec.initContainers[?(@.name=='$init_container')].image}")
  if [[ "$init_image_found" != "$init_image" ]]; then
    failed
    return
  fi

  # Check if main container exists with the correct image
  local main_image_found
  main_image_found=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath="{.spec.containers[?(@.name=='$main_container')].image}")
  if [[ "$main_image_found" != "$main_image" ]]; then
    failed
    return
  fi

  # Check if the shared volume is mounted in the init container
  local init_volume_mount
  init_volume_mount=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath="{.spec.initContainers[?(@.name=='$init_container')].volumeMounts[?(@.name=='$shared_volume')].mountPath}")
  if [[ "$init_volume_mount" != "/data" ]]; then
    failed
    return
  fi

  # Check if the shared volume is mounted in the main container
  local main_volume_mount
  main_volume_mount=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath="{.spec.containers[?(@.name=='$main_container')].volumeMounts[?(@.name=='$shared_volume')].mountPath}")
  if [[ "$main_volume_mount" != "/usr/share/nginx/html" ]]; then
    failed
    return
  fi

  # Check if the expected content is written to shared volume by the init container
  local actual_text
  actual_text=$(kubectl exec -n "$namespace" "$pod_name" -c "$main_container" -- cat /usr/share/nginx/html/index.html 2>/dev/null)
  if [[ "$actual_text" != "$expected_text" ]]; then
    failed
    return
  fi

  solved
  return
}

verify_task7() {
  TASK_NUMBER="7"
  local namespace="default"
  local pod_name="log-processor"
  local sidecar_name="log-forwarder"
  local main_container_name="app"

  # Check if the pod exists
  if ! kubectl get pod "$pod_name" -n "$namespace" &>/dev/null; then
    failed
    return
  fi

  # Verify the initContainer is defined
  local init_containers
  init_containers=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.initContainers[*].name}')
  if [[ ! "$init_containers" =~ $sidecar_name ]]; then
    failed
    return
  fi

  # Verify the initContainer has a restartPolicy set to Always
  local restart_policy
  restart_policy=$(kubectl get pod "$pod_name" -n "$namespace" -o json | jq -r ".spec.initContainers[] | select(.name==\"$sidecar_name\") | .restartPolicy")
  if [[ "$restart_policy" != "Always" ]]; then
    failed
    return
  fi

  # Verify the sidecar is running concurrently
  local sidecar_state
  sidecar_state=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath="{.status.initContainerStatuses[?(@.name=='$sidecar_name')].state.running}")
  if [[ -z "$sidecar_state" ]]; then
    failed
    return
  fi

  # Verify the main container is also running
  local main_state
  main_state=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath="{.status.containerStatuses[?(@.name=='$main_container_name')].state.running}")
  if [[ -z "$main_state" ]]; then
    failed
    return
  fi

  # Validate logs from the main container
  if ! kubectl logs "$pod_name" -n "$namespace" -c "$main_container_name" --tail=5 &>/dev/null; then
    failed
    return
  fi

  # Validate logs from the sidecar container
  if ! kubectl logs "$pod_name" -n "$namespace" -c "$sidecar_name" --tail=5 &>/dev/null; then
    failed
    return
  fi

  solved
  return 0
}

verify_task8() {
  TASK_NUMBER="8"
  local namespace="task8"
  local pod_name="liveness-exec"
  local cmd_expected=("/bin/sh" "-c" "rm -rf /tmp/healthy; sleep 15; touch /tmp/healthy; sleep 7200")
  local pod_age_threshold=15
  local initial_default=5
  local period_default=5
  local failure_threshold_default=1

  # Verify Restart Count is Zero and Retrieve Pod Data
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -n "$namespace" -o=json 2>/dev/null)
  if [[ -z "$pod_json" ]]; then
    failed
    return
  fi

  # Extract fields from pod JSON
  local restart_count
  restart_count=$(echo "$pod_json" | jq -r '.status.containerStatuses[0].restartCount')
  if [[ "$restart_count" -ne 0 ]]; then
    failed
    return
  fi

  # Check Pod Age
  local pod_start_time
  local pod_age
  pod_start_time=$(echo "$pod_json" | jq -r '.status.startTime')
  pod_age=$(( $(date +%s) - $(date -d "$pod_start_time" +%s) ))
  if [[ "$pod_age" -lt "$pod_age_threshold" ]]; then
    failed
    return
  fi

  # Verify Pod Command/Args
  local cmd_actual
  cmd_actual=$(echo "$pod_json" | jq -r '.spec.containers[0].args | join(" ")')
  if [[ "$cmd_actual" != "${cmd_expected[*]}" ]]; then
    failed
    return
  fi

  # Verify Liveness Probe Configuration Has Been Changed
  local initial_delay
  local period
  local failure_threshold
  initial_delay=$(echo "$pod_json" | jq -r '.spec.containers[0].livenessProbe.initialDelaySeconds')
  period=$(echo "$pod_json" | jq -r '.spec.containers[0].livenessProbe.periodSeconds')
  failure_threshold=$(echo "$pod_json" | jq -r '.spec.containers[0].livenessProbe.failureThreshold')
  if [[ "$initial_delay" -eq "$initial_default" ]] && \
     [[ "$period" -eq "$period_default" ]] && \
     [[ "$failure_threshold" -eq "$failure_threshold_default" ]]; then
    failed
    return
  fi

  solved
  return
}

verify_task9() {
  TASK_NUMBER="9"
  local pod_name="nginx-health"
  local namespace="default"

  # Check if the Pod exists
  if ! kubectl get pod "$pod_name" -n "$namespace" > /dev/null 2>&1; then
    failed
    return
  fi

  # Extract the JSON definition of the pod
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -n "$namespace" -o json)

  # Verify the container image
  local container_image
  container_image=$(echo "$pod_json" | jq -r '.spec.containers[0].image')
  if [[ "$container_image" != "nginx:1.21" ]]; then
    failed
    return
  fi

  # Verify the mounted ConfigMap
  local mounted_config
  mounted_config=$(echo "$pod_json" | jq -r '.spec.volumes[] | select(.configMap.name == "nginx-health") | .configMap.name')
  if [[ "$mounted_config" != "nginx-health" ]]; then
    failed
    return
  fi

  # Verify the readiness probe path, port, and timing
  local readiness_path
  readiness_path=$(echo "$pod_json" | jq -r '.spec.containers[0].readinessProbe.httpGet.path')
  local readiness_port
  readiness_port=$(echo "$pod_json" | jq -r '.spec.containers[0].readinessProbe.httpGet.port')
  local readiness_initial_delay
  readiness_initial_delay=$(echo "$pod_json" | jq -r '.spec.containers[0].readinessProbe.initialDelaySeconds')
  local readiness_period
  readiness_period=$(echo "$pod_json" | jq -r '.spec.containers[0].readinessProbe.periodSeconds')

  if [[ "$readiness_path" != "/healthz" ]] || [[ "$readiness_port" != "80" ]]; then
    failed
    return
  fi

  if [[ "$readiness_initial_delay" -ne 3 ]] || [[ "$readiness_period" -ne 5 ]]; then
    failed
    return
  fi

  solved
  return
}

function verify_task10 {
  TASK_NUMBER="10"
  local namespace="task10"
  local pod_name="help-me"

  # Check the pod status
  local pod_status
  pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath='{.status.phase}' 2>/dev/null)
  if [ "$pod_status" != "Running" ]; then
    failed
    return
  fi

  # Check the image
  local image
  image=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath='{.spec.containers[0].image}' 2>/dev/null)
  if [[ "$image" != nginx:* ]]; then
    failed
    return
  fi

  solved
  return
}

verify_task11() {
  TASK_NUMBER="11"

  # Check if the pod `resource-pod` exists in the `limits` namespace
  local pod_exists
  pod_exists=$(kubectl get pod resource-pod -n limits --no-headers --ignore-not-found 2>/dev/null)
  if [ -z "$pod_exists" ]; then
      failed
      return
  fi

  # Get the pod definition
  local pod
  pod=$(kubectl get pod resource-pod -n limits -o json)

  # Check image
  local image
  image=$(echo "$pod" | jq -r '.spec.containers[0].image')
  if [ "$image" != "nginx:1.29.0" ]; then
      failed
      return
  fi

  # Check restart policy
  local restart_policy
  restart_policy=$(echo "$pod" | jq -r '.spec.restartPolicy')
  if [ "$restart_policy" != "Never" ]; then
      failed
      return
  fi

  # Check resource requests
  local request_cpu
  local request_memory
  request_cpu=$(echo "$pod" | jq -r '.spec.containers[0].resources.requests.cpu')
  request_memory=$(echo "$pod" | jq -r '.spec.containers[0].resources.requests.memory')
  if [ "$request_cpu" != "100m" ]; then
      failed
      return
  fi
  if [ "$request_memory" != "128Mi" ]; then
      failed
      return
  fi

  # Check resource limits
  local limit_cpu
  local limit_memory
  limit_cpu=$(echo "$pod" | jq -r '.spec.containers[0].resources.limits.cpu')
  limit_memory=$(echo "$pod" | jq -r '.spec.containers[0].resources.limits.memory')
  if [ "$limit_cpu" != "200m" ]; then
      failed
      return
  fi
  if [ "$limit_memory" != "256Mi" ]; then
      failed
      return
  fi

  solved
  return
}

verify_task12() {
  TASK_NUMBER="12"
  local namespace="limits"
  local limit_range="cpu-limit"
  local pod_name="resource-pod2"

  # Check if there is exactly one LimitRange in the namespace
  local limit_ranges_count
  limit_ranges_count=$(kubectl get limitranges -n "${namespace}" --no-headers | wc -l)
  if [ "${limit_ranges_count}" -ne 1 ]; then
    failed
    return
  fi

  # Get the limit range for the namespace
  local limit_range
  limit_range=$(kubectl get limitranges -n "${namespace}" "${limit_range}" -o json 2>/dev/null)
  if [ -z "${limit_range}" ]; then
    failed
    return
  fi

  local max_cpu max_memory min_cpu min_memory
  max_cpu=$(echo "${limit_range}" | jq -r '.spec.limits[0].max.cpu // empty')
  max_memory=$(echo "${limit_range}" | jq -r '.spec.limits[0].max.memory // empty')
  min_cpu=$(echo "${limit_range}" | jq -r '.spec.limits[0].min.cpu // empty')
  min_memory=$(echo "${limit_range}" | jq -r '.spec.limits[0].min.memory // empty')

  # Check if pod exists
  if ! kubectl get pod "${pod_name}" -n "${namespace}" &>/dev/null; then
    failed
    return
  fi

  # Get the pod's resource limits
  local pod_resources
  pod_resources=$(kubectl get pod "${pod_name}" -n "${namespace}" -o json)
  local pod_cpu pod_memory
  pod_cpu=$(echo "${pod_resources}" | jq -r '.spec.containers[0].resources.limits.cpu // empty')
  pod_memory=$(echo "${pod_resources}" | jq -r '.spec.containers[0].resources.limits.memory // empty')

  # Verify CPU limits
  if [[ -n "${max_cpu}" && "${pod_cpu}" > "${max_cpu}" ]]; then
    failed
    return
  fi
  if [[ -n "${min_cpu}" && "${pod_cpu}" < "${min_cpu}" ]]; then
    failed
    return
  fi

  # Verify Memory limits
  if [[ -n "${max_memory}" && "${pod_memory}" > "${max_memory}" ]]; then
    failed
    return
  fi
  if [[ -n "${min_memory}" && "${pod_memory}" < "${min_memory}" ]]; then
    failed
    return
  fi

  # Check the pod status
  local pod_status
  pod_status=$(kubectl get pod "${pod_name}" -n "${namespace}" -o json | jq -r '.status.phase')
  if [[ "${pod_status}" != "Running" ]]; then
    failed
    return
  fi

  solved
  return
}

# Function to verify Task 13
verify_task13() {
  TASK_NUMBER="13"
  local pod_name="secret-logger"
  local expected_value="good job"
  local secret_name="task13-secret"

  # Check if the pod exists
  if ! kubectl get pod "$pod_name" &>/dev/null; then
    failed
    return
  fi

  # Get the pod definition
  local pod_resources
  pod_resources=$(kubectl get pod "${pod_name}" -n "${namespace}" -o json 2>/dev/null)

  # Check if env or envFrom was used
  local env_from
  env_from=$(echo "${pod_resources}" | jq -r '.spec.containers[0].envFrom[0].secretRef.name // empty')
  env=$(echo "${pod_resources}" | jq -r '.spec.containers[0].env[0].valueFrom.secretKeyRef.name // empty')
  if ! [[ "$env_from" == "$secret_name" || "$env" == "$secret_name" ]]; then
    echo "Neither envFrom nor env is set correctly to 'task13-secret'."
    failed  # Call 'failed' function or exit with an error
    return
  fi

  # Check the pod status
  local pod_status
  pod_status=$(echo "${pod_resources}" | jq -r '.status.phase')
  if [[ "$pod_status" != "Succeeded" ]]; then
    failed
    return
  fi

  # Fetch the pod logs and verify output
  local pod_logs
  pod_logs=$(kubectl logs "$pod_name")
  if [[ "$pod_logs" != "$expected_value" ]]; then
    failed
    return
  fi

  # If all checks pass, mark as solved
  solved
  return
}

verify_task14() {
  TASK_NUMBER="14"
  local namespace="task14"
  local pod_name="selector"
  local label_key="tier"
  local label_value="backend"

  # Ensure that the pod exists in the correct namespace
  if ! kubectl get pod "$pod_name" -n "$namespace" &>/dev/null; then
    failed
    return
  fi

  # Verify that the pod spec includes the correct nodeSelector
  local node_selector
  node_selector=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.nodeSelector.tier}')
  if [[ "$node_selector" != "$label_value" ]]; then
    failed
    return
  fi

  # Verify that the pod is properly scheduled to a node
  local node_name
  node_name=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.nodeName}')
  if [[ -z "$node_name" ]]; then
    failed
    return
  fi

  # Ensure the node has the correct label
  local node_label_value
  node_label_value=$(kubectl get node "$node_name" -o jsonpath="{.metadata.labels.$label_key}")
  if [[ "$node_label_value" != "$label_value" ]]; then
    failed
    return
  fi

  # Ensure the pod is in running state
  local pod_phase
  pod_phase=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}')
  if [[ "$pod_phase" != "Running" ]]; then
    failed
    return
  fi

  solved
  return
}

function verify_task15() {
    TASK_NUMBER="15"

    # Define and initialize local variables
    local namespace="task15"
    local pod_name="affinity"
    local node_label_key="tier"
    local node_label_value="frontend"

    # Check if the namespace exists
    if ! kubectl get namespace "${namespace}" &>/dev/null; then
        failed
        return
    fi

    # Check if the pod exists in the namespace
    if ! kubectl get pod "${pod_name}" -n "${namespace}" &>/dev/null; then
        failed
        return
    fi

    # Check if the pod has the correct nodeAffinity configured
    local affinity_config
    affinity_config=$(kubectl get pod "${pod_name}" -n "${namespace}" -o json | jq '.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution')

    if [[ -z "${affinity_config}" ]] ||
       [[ $(echo "${affinity_config}" | jq -r '.nodeSelectorTerms | length') -eq 0 ]]; then
        failed
        return
    fi

    local match_key
    match_key=$(echo "${affinity_config}" | jq -r '.nodeSelectorTerms[0].matchExpressions[0].key')

    local match_operator
    match_operator=$(echo "${affinity_config}" | jq -r '.nodeSelectorTerms[0].matchExpressions[0].operator')

    local match_values
    match_values=$(echo "${affinity_config}" | jq -r '.nodeSelectorTerms[0].matchExpressions[0].values[]')

    if [[ "${match_key}" != "${node_label_key}" ]] ||
       [[ "${match_operator}" != "In" ]] ||
       [[ "${match_values}" != "${node_label_value}" ]]; then
        failed
        return
    fi

    # Retrieve the node where the pod is running
    local node_name
    node_name=$(kubectl get pod "${pod_name}" -n "${namespace}" -o json | jq -r '.spec.nodeName')

    if [[ -z "${node_name}" ]]; then
        failed
        return
    fi

    # Verify that the node has the expected label
    if ! kubectl get node "${node_name}" -o json | jq -e ".metadata.labels[\"${node_label_key}\"] == \"${node_label_value}\"" &>/dev/null; then
        failed
        return
    fi

    solved
    return
}

verify_task16() {
    TASK_NUMBER="16"

    local pod_name="tolerant"
    local control_plane_label="node-role.kubernetes.io/control-plane"
    local tier_key="tier"
    local forbidden_tiers=("frontend" "backend")
    local expected_message="I'm tolerant!"
    local namespace="default"

    # Check if the pod exists
    local pod_json
    pod_json=$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null || true)
    if [[ -z "$pod_json" ]]; then
        failed
        return
    fi

    # Verify the pod's node affinity
    local affinity
    affinity=$(echo "$pod_json" | jq -r '.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0]')
    if [[ $(echo "$affinity" | jq -r '.key') != "$tier_key" ]] || [[ $(echo "$affinity" | jq -r '.operator') != "NotIn" ]]; then
        failed
        return
    fi

    # Verify forbidden tiers
    local values
    values=$(echo "$affinity" | jq -r '.values[]')
    for forbidden in "${forbidden_tiers[@]}"; do
        if [[ "$values" != *"$forbidden"* ]]; then
            failed
            return
        fi
    done

    # Verify the toleration for control-plane
    local toleration
    toleration=$(echo "$pod_json" | jq -r '.spec.tolerations[] | select(.key=="'"$control_plane_label"'")')
    if [[ $(echo "$toleration" | jq -r '.operator') != "Exists" ]] || [[ $(echo "$toleration" | jq -r '.effect') != "NoSchedule" ]]; then
        failed
        return
    fi

    # Check the restart policy is "Never"
    local restart_policy
    restart_policy=$(echo "$pod_json" | jq -r '.spec.restartPolicy')
    if [[ "$restart_policy" != "Never" ]]; then
        failed
        return
    fi

    # Check the pod's status to ensure it has completed successfully
    local pod_phase
    pod_phase=$(echo "$pod_json" | jq -r '.status.phase')
    if [[ "$pod_phase" != "Succeeded" ]]; then
        failed
        return
    fi

    # Check the pod logs for the expected message
    local pod_logs
    pod_logs=$(kubectl logs "$pod_name" -n "$namespace" 2>/dev/null || true)
    if [[ "$pod_logs" != *"$expected_message"* ]]; then
        failed
        return
    fi

    # If all checks pass, mark as solved
    solved
    return
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
