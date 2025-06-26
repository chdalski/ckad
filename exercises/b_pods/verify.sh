#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

verify_task1() {
  TASKNAME="Task 1"
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
  TASKNAME="Task 2"
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
  TASKNAME="Task 3"
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
  TASKNAME="Task 4"

  local result
  result=$(kubectl apply -f "$(git rev-parse --show-toplevel)/.templates/b_pods/task4/pod.yaml" --dry-run=server 2> /dev/null)
  if  echo "$result" | grep -qi unchanged; then
    solved
  else
    failed
  fi
}

verify_task5() {
  TASKNAME="Task 5"
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
  TASKNAME="Task 6"
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
  TASKNAME="Task 7"
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
  TASKNAME="Task 8"
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
  TASKNAME="Task 9"
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
  TASKNAME="Task 10"
  local namespace="task10"
  local pod_name="help-me"

  # Check the pod status
  local pod_status
  pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath='{.status.phase}')
  if [ "$pod_status" != "Running" ]; then
    failed
    return
  fi

  # Check the image
  local image
  image=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath='{.spec.containers[0].image}')
  if [[ "$image" != nginx:* ]]; then
    failed
    return
  fi

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
exit 0
