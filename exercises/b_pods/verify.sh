#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

verify_task1() {
  TASKNAME="Task 1"
  local NAMESPACE="task1"
  local POD_NAME="nginx"

  STATUS_PHASE=$(kubectl get pods "$POD_NAME" -o jsonpath="{.status.phase}" -n "$NAMESPACE" 2>/dev/null)
  IMAGE=$(kubectl get pods "$POD_NAME" -o jsonpath="{.spec.containers[0].image}" -n "$NAMESPACE" 2>/dev/null)
  if [ "$STATUS_PHASE" == "Running" ] && [ "$IMAGE" == "nginx:1.21" ]; then
    solved
  else
    failed
  fi
}

verify_task2() {
  TASKNAME="Task 2"
  local NAMESPACE="task2"
  local POD_NAME="nginx"
  local IMAGE="nginx:1.21"
  local LABEL_KEY="exposed"
  local LABEL_VALUE="true"
  local PORT=80
  local SERVICE_NAME="nginx"

  # Check if the Pod exists
  if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" &>/dev/null; then
    failed
    return
  fi

  # Check the Pod status (should be "Running")
  POD_STATUS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
  if [[ "$POD_STATUS" != "Running" ]]; then
    failed
    return
  fi

  # Check the image of the container
  POD_IMAGE=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].image}')
  if [[ "$POD_IMAGE" != "$IMAGE" ]]; then
    failed
    return
  fi

  # Check if the Pod has the correct label
  POD_LABEL=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath="{.metadata.labels.$LABEL_KEY}")
  if [[ "$POD_LABEL" != "$LABEL_VALUE" ]]; then
    failed
    return
  fi

  # Check if the Pod exposes the correct container port
  CONTAINER_PORT=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].ports[0].containerPort}')
  if [[ "$CONTAINER_PORT" != "$PORT" ]]; then
    failed
    return
  fi

  # Check if the Service exists
  if ! kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
    failed
    return
  fi

  # Check if the Service targets the correct Pod by the same name (selector)
  SERVICE_SELECTOR=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.selector.exposed}')
  if [[ "$SERVICE_SELECTOR" != "$LABEL_VALUE" ]]; then
    failed
    return
  fi

  # Check if the Service exposes the correct port
  SERVICE_PORT=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
  if [[ "$SERVICE_PORT" != "$PORT" ]]; then
    failed
    return
  fi

  solved
  return
}

verify_task3() {
  TASKNAME="Task 3"
  FILE="busybox-env.txt"
  if kubectl get events -n default 2>/dev/null | grep -q 'pod/busybox' && \
     kubectl get events -n default 2>/dev/null | grep -q 'image "busybox:1.37.0"' && \
     [[ "$(tail -1 < "${FILE}" 2>/dev/null)" == 'pod "busybox" deleted' ]]; then
    solved
  else
    failed
  fi
}

verify_task4() {
  TASKNAME="Task 4"
  TEMPLATE_DIR="$(git rev-parse --show-toplevel)/.templates/b_pods/task_4"
  ACTUAL=$(kubectl apply -f "${TEMPLATE_DIR}/pod.yaml --dry-run=server" 2> /dev/null)
  if  echo "$ACTUAL" | grep -qi unchanged; then
    solved
  else
    failed
  fi
}

verify_task5() {
  TASKNAME="Task 5"
  local POD_NAME="task5-app"
  local CONTAINER_NAME="busybox"
  local IMAGE_NAME="busybox"
  local CONFIG_MAP_NAME="app-config"
  local RESTART_POLICY="Always"
  local COMMAND='["/bin/sh","-c","sleep 7200"]'

  # Verify container name
  CONTAINER=$(kubectl get pod "$POD_NAME" -o jsonpath='{.spec.containers[0].name}' 2>/dev/null)
  if [ "$CONTAINER" != "$CONTAINER_NAME" ]; then
    failed
    return
  fi

  # Verify container image
  CONTAINER_IMAGE=$(kubectl get pod "$POD_NAME" -o jsonpath='{.spec.containers[0].image}')
  if [ "$CONTAINER_IMAGE" != "$IMAGE_NAME" ]; then
    failed
    return
  fi

  # Verify the environment variables are loaded from the ConfigMap
  ENV_SOURCE=$(kubectl get pod "$POD_NAME" -o jsonpath='{.spec.containers[0].envFrom[0].configMapRef.name}')
  if [ "$ENV_SOURCE" != "$CONFIG_MAP_NAME" ]; then
    failed
    return
  fi

  # Verify the restart policy
  POLICY=$(kubectl get pod "$POD_NAME" -o jsonpath='{.spec.restartPolicy}')
  if [ "$POLICY" != "$RESTART_POLICY" ]; then
    failed
    return
  fi

  # Verify the command
  CMD=$(kubectl get pod "$POD_NAME" -o jsonpath='{.spec.containers[0].command}')
  if [[ "$CMD" != "$COMMAND" ]]; then
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
  init_image_found=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath="{.spec.initContainers[?(@.name=='$init_container')].image}")
  if [[ "$init_image_found" != "$init_image" ]]; then
    failed
    return
  fi

  # Check if main container exists with the correct image
  main_image_found=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath="{.spec.containers[?(@.name=='$main_container')].image}")
  if [[ "$main_image_found" != "$main_image" ]]; then
    failed
    return
  fi

  # Check if the shared volume is mounted in the init container
  init_volume_mount=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath="{.spec.initContainers[?(@.name=='$init_container')].volumeMounts[?(@.name=='$shared_volume')].mountPath}")
  if [[ "$init_volume_mount" != "/data" ]]; then
    failed
    return
  fi

  # Check if the shared volume is mounted in the main container
  main_volume_mount=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath="{.spec.containers[?(@.name=='$main_container')].volumeMounts[?(@.name=='$shared_volume')].mountPath}")
  if [[ "$main_volume_mount" != "/usr/share/nginx/html" ]]; then
    failed
    return
  fi

  # Check if the expected content is written to shared volume by the init container
  actual_text=$(kubectl exec -n "$namespace" "$pod_name" -c "$main_container" -- cat /usr/share/nginx/html/index.html 2>/dev/null)
  if [[ "$actual_text" != "$expected_text" ]]; then
    failed
    return
  fi

  solved
  return
}

verify_task7() {
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

verify_task1
verify_task2
verify_task3
verify_task4
verify_task5
verify_task6
verify_task7
exit 0
