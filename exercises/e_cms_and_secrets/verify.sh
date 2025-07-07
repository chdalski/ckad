#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

verify_task1() {
  TASK_NUMBER="1"

  # Expected values
  local configmap_name="app-config"
  local app_mode="production"
  local app_version="1.0"
  local pod_name="app-pod"

  # Verify ConfigMap
  local cm
  cm=$(kubectl get configmap "$configmap_name" -o=json) || { failed; return; }

  local cm_app_mode
  cm_app_mode=$(echo "$cm" | jq -r '.data.APP_MODE') || { failed; return; }
  [[ "$cm_app_mode" == "$app_mode" ]] || { failed; return; }

  local cm_app_version
  cm_app_version=$(echo "$cm" | jq -r '.data.APP_VERSION') || { failed; return; }
  [[ "$cm_app_version" == "$app_version" ]] || { failed; return; }

  # Verify Pod
  local pod
  pod=$(kubectl get pod "$pod_name" -o=json) || { failed; return; }

  local image
  image=$(echo "$pod" | jq -r '.spec.containers[0].image') || { failed; return; }
  [[ "$image" == "nginx:latest" ]] || { failed; return; }

  # Verify Environment Variables in Pod Execution
  local pod_envs
  pod_envs=$(kubectl exec "$pod_name" -- env | grep APP_) || { failed; return; }

  echo "$pod_envs" | grep -q "^APP_MODE=$app_mode$" || { failed; return; }
  echo "$pod_envs" | grep -q "^APP_VERSION=$app_version$" || { failed; return; }

  # All checks passed
  solved
  return
}

verify_task2() {
  TASK_NUMBER="2"

  local expected_cm_name="html-config"
  local expected_pod_name="web-pod"
  local expected_image="nginx:latest"
  local expected_mount_path="/usr/share/nginx/html"
  local expected_index_file="index.html"
  local expected_error_file="error.html"
  local expected_index_content="<h1>Welcome to Kubernetes</h1>"
  local expected_error_content="<h1>Error Page</h1>"
  local cm pod image mount_path configmap_name file_content

  # Check ConfigMap exists and has correct data
  cm=$(kubectl get configmap "$expected_cm_name" -o json 2>/dev/null) || { failed; return; }
  file_content=$(echo "$cm" | jq -r --arg f "$expected_index_file" '.data[$f]') || { failed; return; }
  [ "$file_content" = "$expected_index_content" ] || { failed; return; }
  file_content=$(echo "$cm" | jq -r --arg f "$expected_error_file" '.data[$f]') || { failed; return; }
  [ "$file_content" = "$expected_error_content" ] || { failed; return; }

  # Check Pod exists, uses correct image, and mounts ConfigMap at correct path
  pod=$(kubectl get pod "$expected_pod_name" -o json 2>/dev/null) || { failed; return; }
  image=$(echo "$pod" | jq -r '.spec.containers[0].image') || { failed; return; }
  [ "$image" = "$expected_image" ] || { failed; return; }
  volume_name=$(echo "$pod" | jq -r --arg cm "$expected_cm_name" '.spec.volumes[] | select(.configMap.name==$cm) | .name') || { failed; return; }
  [ -n "$volume_name" ] || { failed; return; }
  mount_path=$(echo "$pod" | jq -r --arg v "$volume_name" '.spec.containers[0].volumeMounts[] | select(.name==$v) | .mountPath') || { failed; return; }
  [ "$mount_path" = "$expected_mount_path" ] || { failed; return; }

  # Check files are present in the running container with correct content
  kubectl exec "$expected_pod_name" -- test -f "$expected_mount_path/$expected_index_file" || { failed; return; }
  kubectl exec "$expected_pod_name" -- test -f "$expected_mount_path/$expected_error_file" || { failed; return; }
  file_content=$(kubectl exec "$expected_pod_name" -- cat "$expected_mount_path/$expected_index_file" 2>/dev/null) || { failed; return; }
  [ "$file_content" = "$expected_index_content" ] || { failed; return; }
  file_content=$(kubectl exec "$expected_pod_name" -- cat "$expected_mount_path/$expected_error_file" 2>/dev/null) || { failed; return; }
  [ "$file_content" = "$expected_error_content" ] || { failed; return; }

  solved
  return
}

verify_task3() {
  TASK_NUMBER="3"

  # Define expected values
  local expected_secret_name="db-credentials"
  local expected_username="admin"
  local expected_password="SuperSecretPassword"
  local expected_pod_name="db-pod"
  local expected_image="nginx:latest"

  # Check if the Secret exists
  local secret_exists
  secret_exists=$(kubectl get secret "${expected_secret_name}" -o name 2>/dev/null) || { failed; return; }

  if [[ -z "${secret_exists}" ]]; then
    failed
    return
  fi

  # Check Secret data
  local actual_username
  actual_username=$(kubectl get secret "${expected_secret_name}" -o jsonpath='{.data.username}' | base64 --decode) || { failed; return; }

  local actual_password
  actual_password=$(kubectl get secret "${expected_secret_name}" -o jsonpath='{.data.password}' | base64 --decode) || { failed; return; }

  if [[ "${actual_username}" != "${expected_username}" || "${actual_password}" != "${expected_password}" ]]; then
    failed
    return
  fi

  # Check if the Pod exists
  local pod_exists
  pod_exists=$(kubectl get pod "${expected_pod_name}" -o name 2>/dev/null) || { failed; return; }

  if [[ -z "${pod_exists}" ]]; then
    failed
    return
  fi

  # Check Pod image
  local actual_image
  actual_image=$(kubectl get pod "${expected_pod_name}" -o jsonpath='{.spec.containers[0].image}') || { failed; return; }

  if [[ "${actual_image}" != "${expected_image}" ]]; then
    failed
    return
  fi

  # Check environment variables in the Pod
  local pod_ready
  pod_ready=$(kubectl get pod "${expected_pod_name}" -o jsonpath='{.status.containerStatuses[0].ready}') || { failed; return; }

  if [[ "${pod_ready}" != "true" ]]; then
    failed
    return
  fi

  # Verify environment variables are set correctly
  local env_username
  env_username=$(kubectl exec "${expected_pod_name}" -- env | grep "username=" | cut -d= -f2) || { failed; return; }

  local env_password
  env_password=$(kubectl exec "${expected_pod_name}" -- env | grep "password=" | cut -d= -f2) || { failed; return; }

  if [[ "${env_username}" != "${expected_username}" || "${env_password}" != "${expected_password}" ]]; then
    failed
    return
  fi

  # All checks passed
  solved
  return
}

verify_task4() {
  TASK_NUMBER="4"
  local secret_name="tls-secret"
  local pod_name="secure-pod"
  local expected_image="redis:latest"
  local expected_mount_path="/etc/tls"
  local local_crt_file="task4.crt"
  local local_key_file="task4.key"

  # Get secret as JSON
  local secret_json
  secret_json="$(kubectl get secret "$secret_name" -o json 2>/dev/null)" || { failed; return; }

  # Verify secret contains expected data fields
  echo "$secret_json" | jq -e '.data["tls.crt"] and .data["tls.key"]' >/dev/null || { failed; return; }

  # Get pod as JSON
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -o json 2>/dev/null)" || { failed; return; }

  # Verify pod has only one container and uses the expected image
  echo "$pod_json" | jq -e '.spec.containers | length == 1' >/dev/null || { failed; return; }
  echo "$pod_json" | jq -e --arg img "$expected_image" '.spec.containers[0].image == $img' >/dev/null || { failed; return; }

  # Verify pod contains a volume that uses the expected secret
  local volume_name
  volume_name="$(echo "$pod_json" | jq -r --arg secret "$secret_name" '.spec.volumes[] | select(.secret.secretName == $secret) | .name')" || { failed; return; }
  [ -n "$volume_name" ] || { failed; return; }

  # Verify container has a volumeMount with the name of the volume and the expected mount path
  echo "$pod_json" | jq -e --arg vol "$volume_name" --arg path "$expected_mount_path" \
    '.spec.containers[0].volumeMounts[] | select(.name == $vol and .mountPath == $path)' >/dev/null || { failed; return; }

  # Verify the files are mounted in the container and match the local files (base64 compare)
  local local_crt_b64
  local_crt_b64="$(base64 -w0 < "$local_crt_file")" || { failed; return; }
  pod_crt_b64="$(kubectl exec "$pod_name" -- sh -c "base64 -w0 < '$expected_mount_path/tls.crt'" 2>/dev/null)" || { failed; return; }
  [ "$local_crt_b64" = "$pod_crt_b64" ] || { failed; return; }

  local local_key_b64
  local_key_b64="$(base64 -w0 < "$local_key_file")" || { failed; return; }
  pod_key_b64="$(kubectl exec "$pod_name" -- sh -c "base64 -w0 < '$expected_mount_path/tls.key'" 2>/dev/null)" || { failed; return; }
  [ "$local_key_b64" = "$pod_key_b64" ] || { failed; return; }

  solved
  return
}

verify_task5() {
  TASK_NUMBER="5"

  local configmap_name="message-config"
  local configmap_key="message"
  local configmap_value="Hello, Kubernetes"
  local pod_name="message-pod"
  local expected_image="busybox"
  local expected_command='["sh","-c","while true; do echo \"$MESSAGE\"; sleep 5; done"]'
  local env_name="MESSAGE"
  local env_configmap_name="message-config"
  local env_configmap_key="message"

  local cm_json
  cm_json=$(kubectl get configmap "$configmap_name" -o json) || { failed; return; }
  echo "$cm_json" | jq -e --arg key "$configmap_key" --arg val "$configmap_value" \
    '.data[$key] == $val' > /dev/null || { failed; return; }

  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -o json) || { failed; return; }
  echo "$pod_json" | jq -e --arg img "$expected_image" \
    '.spec.containers[0].image == $img' > /dev/null || { failed; return; }
  echo "$pod_json" | jq -e --argjson cmd "$expected_command" \
    '.spec.containers[0].command == $cmd' > /dev/null || { failed; return; }
  echo "$pod_json" | jq -e --arg env "$env_name" --arg cm "$env_configmap_name" --arg key "$env_configmap_key" \
    '.spec.containers[0].env[] | select(.name == $env) | .valueFrom.configMapKeyRef.name == $cm and .valueFrom.configMapKeyRef.key == $key' > /dev/null || { failed; return; }

  solved
  return
}

verify_task1
verify_task2
verify_task3
verify_task4
verify_task5
exit 0
