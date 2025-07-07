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
  local image_name="nginx:1.29.0"
  local pv_storage="1Gi"
  local pvc_request="500Mi"
  local access_mode="ReadWriteOnce"
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
  local app_container_image="nginx:1.29.0"
  local app_html_mount_path="/usr/share/nginx/html"
  local app_config_mount_path="/etc/nginx/conf.d"
  local expected_config_map_name="app-config"

  # Step 1: Get the pod as JSON by its name
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null) || { failed; return; }

  # Step 2: Get the initContainer[0] and verify it has a volumeMount[0] with the expected mountPath
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

  # Step 5: Get the containers[0] and make sure it has the expected name
  local app_container_name_actual
  app_container_name_actual=$(echo "$pod_json" | jq -r '.spec.containers[0].name' 2>/dev/null)
  [[ "$app_container_name_actual" == "$app_container_name" ]] || { failed; return; }

  # Step 6: Get the containers[0] and make sure it has the expected image
  local app_container_image_actual
  app_container_image_actual=$(echo "$pod_json" | jq -r '.spec.containers[0].image' 2>/dev/null)
  [[ "$app_container_image_actual" == "$app_container_image" ]] || { failed; return; }

  # Step 7: Verify the app container has a volumeMount with the same volume as in step 3, mounted to the expected path
  local app_container_html_mount
  app_container_html_mount=$(echo "$pod_json" | jq -r ".spec.containers[0].volumeMounts[] | select(.name == \"$init_container_volume_name\" and .mountPath == \"$app_html_mount_path\")" 2>/dev/null)
  [[ -n "$app_container_html_mount" ]] || { failed; return; }

  # Step 8: Verify the app container has another volume mounted to the expected path
  local config_volume_mount
  config_volume_mount=$(echo "$pod_json" | jq -r ".spec.containers[0].volumeMounts[] | select(.mountPath == \"$app_config_mount_path\").name" 2>/dev/null)
  [[ -n "$config_volume_mount" ]] || { failed; return; }

  # Step 9: Take the name from step 7 and verify the corresponding volume points to the configMap with the expected name
  local config_map_name_actual
  config_map_name_actual=$(echo "$pod_json" | jq -r ".spec.volumes[] | select(.name == \"$config_volume_mount\").configMap.name" 2>/dev/null)
  [[ "$config_map_name_actual" == "$expected_config_map_name" ]] || { failed; return; }

  # Step 10: Verify curl execution by checking nginx access log
  local nginx_access_log
  nginx_access_log=$(kubectl exec -it init-cache -c app -- cat /var/log/nginx/host.access.log 2>/dev/null)
  [[ "$nginx_access_log" == *"127.0.0.1"*"GET"*"200"*"curl"* ]] || { failed; return; }

  solved
  return
}

verify_task3() {
  TASK_NUMBER="3"

  local pod_name="task3-app"
  local pvc_name="task3-pvc"
  local pv_name="task3-pv"
  local task_file_name="task3.txt"
  local expected_text="nginx version: nginx/1.29.0nginx version: nginx/1.29.0"

  # Check if the pod is deleted
  local pod_status
  pod_status=$(kubectl get pod "${pod_name}" -o json --ignore-not-found | jq -r '.metadata.name')
  if [[ -n "${pod_status}" ]]; then
    failed
    return
  fi

  # Check if the PVC is deleted
  local pvc_status
  pvc_status=$(kubectl get pvc "${pvc_name}" -o json --ignore-not-found | jq -r '.metadata.name')
  if [[ -n "${pvc_status}" ]]; then
    failed
    return
  fi

  # Check if the PV is deleted
  local pv_status
  pv_status=$(kubectl get pv "${pv_name}" -o json --ignore-not-found | jq -r '.metadata.name')
  if [[ -n "${pv_status}" ]]; then
    failed
    return
  fi

  # Check if the task3.txt file exists
  local local_storage_path
  local_storage_path="$(git rev-parse --show-toplevel)/.cluster/mounts/storage"
  if [[ ! -f "${local_storage_path}/${task_file_name}" ]]; then
    failed
    return
  fi

  # Check the content of task3.txt
  local file_content
  file_content=$(cat "${local_storage_path}/${task_file_name}")
  if [[ "${file_content}" != "${expected_text}" ]]; then
    failed
    return
  fi

  # All checks passed
  solved
  return
}

verify_task4() {
  TASK_NUMBER="4"

  # Define local variables
  local namespace="config"
  local pod_name="app"
  local expected_image="nginx:1.29.0"
  local mount_path="/etc/app"
  local configmap_name="app-config"
  local config_key="config"
  local expected_file_path="${mount_path}/config.json"

  # Get the pod as JSON by its name
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null) || { failed; return; }

  # Verify the pod is in the correct namespace and is running
  local pod_status
  pod_status=$(echo "${pod_json}" | jq -r '.status.phase')
  if [[ "$pod_status" != "Running" ]]; then
    failed
    return
  fi

  # Verify the pod's image is as expected
  local pod_image
  pod_image=$(echo "${pod_json}" | jq -r '.spec.containers[0].image')
  if [[ "$pod_image" != "$expected_image" ]]; then
    failed
    return
  fi

  # Verify there's a volumeMount to path /etc/app
  local mount_check
  mount_check=$(echo "${pod_json}" | \
    jq -r --arg path "$mount_path" '.spec.containers[0].volumeMounts[] | select(.mountPath == $path)')
  if [[ -z "$mount_check" ]]; then
    failed
    return
  fi

  # Use the volumeMounts name to get the volume name
  local volume_name
  volume_name=$(echo "${pod_json}" | \
    jq -r --arg path "$mount_path" '.spec.containers[0].volumeMounts[] | select(.mountPath == $path) | .name')
  if [[ -z "$volume_name" ]]; then
    failed
    return
  fi

  # Verify the volume mounts the right config map and has the items configured as expected
  local cm_check
  cm_check=$(echo "${pod_json}" | \
    jq -r --arg vol "$volume_name" --arg cm "$configmap_name" --arg key "$config_key" \
      '.spec.volumes[] | select(.name == $vol) | (.configMap.name == $cm and .configMap.items[0].key == $key and .configMap.items[0].path == "config.json")')
  if [[ "$cm_check" != "true" ]]; then
    failed
    return
  fi

  # Get the value of the key from the ConfigMap
  local key_value
  key_value=$(kubectl get configmap "$configmap_name" -n "$namespace" -o json | jq -r --arg key "$config_key" '.data[$key]')
  if [[ -z "$key_value" ]]; then
    failed
    return
  fi

  # Verify the content of the file inside the container
  local file_content
  file_content=$(kubectl exec -n "$namespace" "$pod_name" -- cat "$expected_file_path" 2>/dev/null)
  if [[ "$file_content" != "$key_value" ]]; then
    failed
    return
  fi

  # If all the checks pass
  solved
  return
}

verify_task5() {
  # Define task number as non-local variable
  TASK_NUMBER="5"

  # Define local variables
  local namespace="database"
  local pod_name="app"
  local expected_image="redis:8.0.2"
  local secret_name="db-credentials"
  local mount_path="/etc/credentials"
  local volume_name="secret-vol"

  # Get the pod definition in JSON format
  local pod_definition
  pod_definition=$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null) || { failed; return; }

  # Verify the pod is using the correct image
  local image
  image=$(echo "$pod_definition" | jq -r '.spec.containers[0].image') || { failed; return; }
  [[ "$image" == "$expected_image" ]] || { failed; return; }

  # Verify the pod has the correct volumeMount
  local volume_mount_path
  volume_mount_path=$(echo "$pod_definition" | jq -r '.spec.containers[0].volumeMounts[] | select(.name=="'"$volume_name"'") | .mountPath') || { failed; return; }
  [[ "$volume_mount_path" == "$mount_path" ]] || { failed; return; }

  # Verify the volume is backed by the correct Secret
  local secret_ref
  secret_ref=$(echo "$pod_definition" | jq -r '.spec.volumes[] | select(.name=="'"$volume_name"'") | .secret.secretName') || { failed; return; }
  [[ "$secret_ref" == "$secret_name" ]] || { failed; return; }

  # Get the list of files in the container's mounted directory
  local mounted_files
  mounted_files=$(kubectl exec -n $namespace -it $pod_name -- ls $mount_path 2>/dev/null) || { failed; return; }

  # Verify all keys from the Secret are mounted (fetching Secret data keys)
  local secret_keys
  secret_keys=$(kubectl get secret $secret_name -n $namespace -o json | jq -r '.data | keys | .[]') || { failed; return; }

  # Check that each key is present in the container's mounted directory as a file
  for key in $secret_keys; do
    echo "$mounted_files" | tr ' ' '\n' | grep -Fwq "$key" || { failed; return; }
  done

  # If all checks passed, mark the task as solved
  solved
  return
}

verify_task6() {
  TASK_NUMBER="6"

  # Define local variables
  local namespace="storage-limited"
  local pv_name="quota"
  local pvc_count=2
  local expected_request_storage="2Gi"
  local expected_pvc_limit=2
  local expected_pv_capacity="3Gi"
  local pv_path="/tmp/backend"
  local node_affinity_key="tier"
  local node_affinity_value="backend"

  # Verify the namespace exists
  kubectl get ns "${namespace}" &>/dev/null || { failed; return; }

  # Get the list of quotas
  local quota_list
  quota_list=$(kubectl get quota -n "$namespace" -o json 2>/dev/null) || { failed; return; }

  # Verify that one quota exists in the namespace
  local quota_count
  quota_count=$(echo "$quota_list" | jq '.items | length')
  if [ "$quota_count" -ne 1 ]; then
    failed
    return
  fi

  # # Verify the quota's definition
  local quota_json
  quota_json=$(echo "$quota_list" | jq '.items[0]')
  if [[ "$(jq -r '.spec.hard["requests.storage"]' <<< "${quota_json}")" != "${expected_request_storage}" || \
        "$(jq -r '.spec.hard["persistentvolumeclaims"]' <<< "${quota_json}")" != "${expected_pvc_limit}" ]]; then
    failed
    return
  fi

  # Verify the persistent volume's definition
  local pv_json
  pv_json=$(kubectl get pv "${pv_name}" -o json 2>/dev/null) || { failed; return; }
  if [[ "$(jq -r '.spec.capacity.storage' <<< "${pv_json}")" != "${expected_pv_capacity}" || \
        "$(jq -r '.spec.local.path' <<< "${pv_json}")" != "${pv_path}" || \
        "$(jq -r '.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].key' <<< "${pv_json}")" != "${node_affinity_key}" || \
        "$(jq -r '.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]' <<< "${pv_json}")" != "${node_affinity_value}" ]]; then
    failed
    return
  fi

  # Verify the correct number of PVCs exist in the namespace
  local pvc_count_actual
  pvc_count_actual=$(kubectl get pvc -n "${namespace}" -o json | jq '.items | length')
  if [[ "${pvc_count_actual}" -ne "${pvc_count}" ]]; then
    failed
    return
  fi

  # If all checks are successful
  solved
  return
}

function verify_task7() {
  TASK_NUMBER="7"

  # Fixed values
  local expected_host_path="/mnt/projects"
  local expected_requested_storage="2Gi"
  local expected_sub_path="project1"
  local expected_mount_path="/projects"
  local expected_image_prefix="nginx"

  # Step 1: Verify there is a PV that mounts /mnt/projects as hostPath path
  local pv_name
  pv_name=$(kubectl get pv -o json | jq -r --arg path "$expected_host_path" '.items[] | select(.spec.hostPath.path == $path) | .metadata.name') || { failed; return; }
  [ -z "$pv_name" ] && { failed; return; }

  local hostpath
  hostpath=$(kubectl get pv "$pv_name" -o json | jq -r '.spec.hostPath.path') || { failed; return; }
  [ "$hostpath" != "$expected_host_path" ] && { failed; return; }

  # Step 2: Verify if there is a PVC that uses that PV and requests 2Gi of storage
  local pvc_name
  pvc_name=$(kubectl get pvc -o json | jq -r --arg pv_name "$pv_name" --arg requested_storage "$expected_requested_storage" '.items[] | select(.spec.volumeName == $pv_name and .spec.resources.requests.storage == $requested_storage) | .metadata.name') || { failed; return; }
  [ -z "$pvc_name" ] && { failed; return; }

  local requested_storage
  requested_storage=$(kubectl get pvc "$pvc_name" -o json | jq -r '.spec.resources.requests.storage') || { failed; return; }
  [ "$requested_storage" != "$expected_requested_storage" ] && { failed; return; }

  # Step 3: Verify if there's a pod using that PVC and fulfills the requirements
  local pod_name
  pod_name=$(kubectl get pod -o json | jq -r --arg pvc_name "$pvc_name" '.items[] | select(.spec.volumes[]?.persistentVolumeClaim?.claimName == $pvc_name) | .metadata.name') || { failed; return; }
  [ -z "$pod_name" ] && { failed; return; }

  local subpath
  subpath=$(kubectl get pod "$pod_name" -o json | jq -r --arg mount_path "$expected_mount_path" '.spec.containers[0].volumeMounts[] | select(.mountPath == $mount_path) | .subPath') || { failed; return; }
  [ "$subpath" != "$expected_sub_path" ] && { failed; return; }

  local image
  image=$(kubectl get pod "$pod_name" -o json | jq -r '.spec.containers[0].image') || { failed; return; }
  [[ "$image" != "$expected_image_prefix"* ]] && { failed; return; }

  # Step 4: Verify there are files created inside the /mnt/projects folder in the container
  local created_files
  created_files=$(kubectl exec "$pod_name" -- bash -c "ls $expected_mount_path") || { failed; return; }
  [ -z "$created_files" ] && { failed; return; }

  # If all checks pass, task is solved
  solved
}

verify_task1
verify_task2
verify_task3
verify_task4
verify_task5
verify_task6
verify_task7
exit 0
