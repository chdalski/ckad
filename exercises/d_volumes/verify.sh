#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

function verify_task1() {
  # Declare task number
  TASK_NUMBER="1"

  # Local variable declarations
  local pv_name="data-pv"
  local pvc_name="data-pvc"
  local pod_name="data-pod"
  local image_name="nginx"
  local pv_storage="1Gi"
  local pvc_request="500Mi"
  local access_mode="ReadOnlyMany"
  local pv_path="/mnt/data"
  local pvc_mount_path="/data"

  # Verify PersistentVolume exists and matches the spec
  local pv
  pv=$(kubectl get pv "$pv_name" -o json 2>/dev/null) || { failed; return; }
  if [ "$(echo "$pv" | jq -r '.metadata.name')" != "$pv_name" ] || \
     [ "$(echo "$pv" | jq -r '.spec.capacity.storage')" != "$pv_storage" ] || \
     [ "$(echo "$pv" | jq -r '.spec.accessModes[0]')" != "$access_mode" ] || \
     [ "$(echo "$pv" | jq -r '.spec.hostPath.path')" != "$pv_path" ]; then
    failed
    return
  fi

  # Verify PersistentVolumeClaim exists and matches the spec
  local pvc
  pvc=$(kubectl get pvc "$pvc_name" -o json 2>/dev/null) || { failed; return; }
  if [ "$(echo "$pvc" | jq -r '.metadata.name')" != "$pvc_name" ] || \
     [ "$(echo "$pvc" | jq -r '.spec.volumeName')" != "$pv_name" ] || \
     [ "$(echo "$pvc" | jq -r '.spec.accessModes[0]')" != "$access_mode" ] || \
     [ "$(echo "$pvc" | jq -r '.spec.resources.requests.storage')" != "$pvc_request" ]; then
    failed
    return
  fi

  # Verify Pod exists and matches the spec
  local pod
  pod=$(kubectl get pod "$pod_name" -o json 2>/dev/null) || { failed; return; }
  if [ "$(echo "$pod" | jq -r '.metadata.name')" != "$pod_name" ] || \
     [ "$(echo "$pod" | jq -r '.spec.containers[0].image')" != "$image_name" ] || \
     [ "$(echo "$pod" | jq -r '.spec.containers[0].volumeMounts[0].mountPath')" != "$pvc_mount_path" ] || \
     [ "$(echo "$pod" | jq -r '.spec.volumes[0].persistentVolumeClaim.claimName')" != "$pvc_name" ]; then
    failed
    return
  fi

  # If all checks pass, mark the task as solved
  solved
  return
}

function verify_task2() {
  TASK_NUMBER="2"

  # Define expected values
  local pod_name="init-cache"
  local namespace="default"
  local init_container_mount_path="/cache"
  local app_container_name="app"
  local app_html_mount_path="/usr/share/nginx/html"
  local app_config_mount_path="/etc/nginx/conf.d"
  local expected_config_map_name="app-config"

  # Step 1: Get the pod as JSON by its name
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null) || { failed; return; }

  # Step 2: Get the initContainer[0] and verify it has a volumeMount[0] with mountPath "/cache"
  local init_container_mount_path_actual
  init_container_mount_path_actual=$(echo "$pod_json" | jq -r '.spec.initContainers[0].volumeMounts[0].mountPath' 2>/dev/null)
  [[ "$init_container_mount_path_actual" == "$init_container_mount_path" ]] || { failed; return; }

  # Step 3: Use the name of the volumeMount[0] from the initContainer to determine the volume name
  local init_container_volume_name
  init_container_volume_name=$(echo "$pod_json" | jq -r '.spec.initContainers[0].volumeMounts[0].name' 2>/dev/null)
  [[ -n "$init_container_volume_name" ]] || { failed; return; }

  # Step 4: Verify the volume is an emptyDir
  local empty_dir_check
  empty_dir_check=$(echo "$pod_json" | jq -r ".spec.volumes[] | select(.name == \"$init_container_volume_name\").emptyDir" 2>/dev/null)
  [[ "$empty_dir_check" != "null" ]] || { failed; return; }

  # Step 5: Get the containers[0] and make sure it is named "app"
  local app_container_name_actual
  app_container_name_actual=$(echo "$pod_json" | jq -r '.spec.containers[0].name' 2>/dev/null)
  [[ "$app_container_name_actual" == "$app_container_name" ]] || { failed; return; }

  # Step 6: Verify the app container has a volumeMount with the same volume as in step 3, mounted to "/usr/share/nginx/html"
  local app_container_html_mount
  app_container_html_mount=$(echo "$pod_json" | jq -r ".spec.containers[0].volumeMounts[] | select(.name == \"$init_container_volume_name\" and .mountPath == \"$app_html_mount_path\")" 2>/dev/null)
  [[ -n "$app_container_html_mount" ]] || { failed; return; }

  # Step 7: Verify the app container has another volume mount with path "/etc/nginx/conf.d"
  local config_volume_mount
  config_volume_mount=$(echo "$pod_json" | jq -r ".spec.containers[0].volumeMounts[] | select(.mountPath == \"$app_config_mount_path\").name" 2>/dev/null)
  [[ -n "$config_volume_mount" ]] || { failed; return; }

  # Step 8: Take the name from step 7 and verify the corresponding volume points to the configMap with name "app-config"
  local config_map_name_actual
  config_map_name_actual=$(echo "$pod_json" | jq -r ".spec.volumes[] | select(.name == \"$config_volume_mount\").configMap.name" 2>/dev/null)
  [[ "$config_map_name_actual" == "$expected_config_map_name" ]] || { failed; return; }

  # Step 9: Verify curl execution by checking nginx access log
  local nginx_access_log
  nginx_access_log=$(kubectl exec -it init-cache -c app -- cat /var/log/nginx/host.access.log 2>/dev/null)
  [[ "$nginx_access_log" == *"127.0.0.1"*"GET"*"200"*"curl"* ]] || { failed; return; }

  solved
  return
}

verify_task1
verify_task2
exit 0
