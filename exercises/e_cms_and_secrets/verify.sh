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
  local expected_image="nginx:1.29.0"

  # Verify ConfigMap
  local cm
  cm=$(kubectl get configmap "$configmap_name" -o json 2>/dev/null) || { failed; return; }

  local cm_app_mode
  cm_app_mode=$(echo "$cm" | jq -r '.data.APP_MODE') || { failed; return; }
  [[ "$cm_app_mode" == "$app_mode" ]] || { failed; return; }

  local cm_app_version
  cm_app_version=$(echo "$cm" | jq -r '.data.APP_VERSION') || { failed; return; }
  [[ "$cm_app_version" == "$app_version" ]] || { failed; return; }

  # Verify Pod
  local pod
  pod=$(kubectl get pod "$pod_name" -o json 2>/dev/null) || { failed; return; }

  local image
  image=$(echo "$pod" | jq -r '.spec.containers[0].image') || { failed; return; }
  [[ "$image" == "$expected_image" ]] || { failed; return; }

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
  local expected_image="nginx:1.29.0"
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
  local expected_image="nginx:1.29.0"

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
  local expected_image="redis:8.0.2"
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
  local expected_image="busybox:1.37.0"
  local expected_command="sh -c while true; do echo \"$MESSAGE\"; sleep 5; done"
  local env_name="MESSAGE"
  local env_configmap_name="message-config"
  local env_configmap_key="message"

  local cm_json
  cm_json=$(kubectl get configmap "$configmap_name" -o json 2>/dev/null) || { failed; return; }
  echo "$cm_json" | jq -e --arg key "$configmap_key" --arg val "$configmap_value" \
    '.data[$key] == $val' > /dev/null || { failed; return; }

  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -o json 2>/dev/null) || { failed; return; }
  echo "$pod_json" | jq -e --arg img "$expected_image" \
    '.spec.containers[0].image == $img' > /dev/null || { failed; return; }
  [[ $(echo "$pod_json" | jq -r '.spec.containers[0].command | join(" ")') != "$expected_command" ]] || { failed; return; }
  echo "$pod_json" | jq -e --arg env "$env_name" --arg cm "$env_configmap_name" --arg key "$env_configmap_key" \
    '.spec.containers[0].env[] | select(.name == $env) | .valueFrom.configMapKeyRef.name == $cm and .valueFrom.configMapKeyRef.key == $key' > /dev/null || { failed; return; }

  solved
  return
}

verify_task6() {
  TASK_NUMBER="6"

  local secret_name="api-secret"
  local configmap1_name="frontend-config"
  local configmap2_name="backend-config"
  local pod_name="complex-pod"
  local expected_api_key="12345"
  local expected_title="Frontend"
  local expected_endpoint="http://backend.local"
  local secret_json configmap1_json configmap2_json pod_json pod_env expected_api_key_b64

  # Verify Secret exists and get as json
  secret_json=$(kubectl get secret "$secret_name" -o json 2>/dev/null) || { failed; return; }

  # Verify Secret contains expected API_KEY value (base64 encoded)
  expected_api_key_b64=$(echo -n "$expected_api_key" | base64)
  echo "$secret_json" | jq -e --arg key "$expected_api_key_b64" '.data.API_KEY == $key' | grep -q true || { failed; return; }

  # Verify ConfigMap frontend-config exists and get as json
  configmap1_json=$(kubectl get configmap "$configmap1_name" -o json 2>/dev/null) || { failed; return; }

  # Verify ConfigMap contains expected TITLE value
  echo "$configmap1_json" | jq -e --arg val "$expected_title" '.data.TITLE == $val' | grep -q true || { failed; return; }

  # Verify ConfigMap backend-config exists and get as json
  configmap2_json=$(kubectl get configmap "$configmap2_name" -o json) || { failed; return; }
  # Verify ConfigMap contains expected ENDPOINT value
  echo "$configmap2_json" | jq -e --arg val "$expected_endpoint" '.data.ENDPOINT == $val' | grep -q true || { failed; return; }

  # Verify Pod exists and get as json
  pod_json=$(kubectl get pod "$pod_name" -o json) || { failed; return; }

  # Verify Pod uses nginx:1.29.0 image
  echo "$pod_json" | jq -e '.spec.containers[0].image == "nginx:1.29.0"' | grep -q true || { failed; return; }

  # Verify Pod is running and has expected env vars
  pod_env=$(kubectl exec "$pod_name" -- env) || { failed; return; }
  echo "$pod_env" | grep -q "^TITLE=$expected_title$" || { failed; return; }
  echo "$pod_env" | grep -q "^ENDPOINT=$expected_endpoint$" || { failed; return; }
  echo "$pod_env" | grep -q "^API_KEY=$expected_api_key$" || { failed; return; }

  solved
  return
}

verify_task7() {
  TASK_NUMBER="7"

  local namespace="volume"
  local cm_name="app-config"
  local secret_name="app-secret"
  local pod_name="volume-pod"
  local expected_container_image="redis:8.0.2"
  local expected_cm_key="config.yml"
  local expected_cm_value="application: setting1"
  local expected_secret_key="password"
  local expected_secret_value_base64
  expected_secret_value_base64=$(echo -n "awesome_and_secure" | base64)
  local expected_config_mount_path="/etc/config"
  local expected_secret_mount_path="/etc/secret"
  local cm_json secret_json pod_json config_mount_name secret_mount_name

  # Verify ConfigMap exists and get its json
  cm_json="$(kubectl get configmap "$cm_name" -n "$namespace" -o json 2>/dev/null)" || { failed; return; }

  # Verify ConfigMap contains expected data
  echo "$cm_json" | jq -e --arg key "$expected_cm_key" --arg val "$expected_cm_value" \
    '.data[$key] == $val' > /dev/null || { failed; return; }

  # Verify Secret exists and get its json
  secret_json="$(kubectl get secret "$secret_name" -n "$namespace" -o json 2>/dev/null)" || { failed; return; }

  # Verify Secret contains expected data (base64 encoded)
  echo "$secret_json" | jq -e --arg key "$expected_secret_key" --arg val "$expected_secret_value_base64" \
    '.data[$key] == $val' > /dev/null || { failed; return; }

  # Verify Pod exists and get its json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || { failed; return; }

  # Verify Pod uses the expected image
  echo "$pod_json" | jq -e --arg image "$expected_container_image" \
    '.spec.containers[0].image == $image' > /dev/null || { failed; return; }

  # Get volumeMounts and volumes
  config_mount_name="$(echo "$pod_json" | jq -r --arg path "$expected_config_mount_path" \
    '.spec.containers[0].volumeMounts[] | select(.mountPath == $path) | .name')" || { failed; return; }
  secret_mount_name="$(echo "$pod_json" | jq -r --arg path "$expected_secret_mount_path" \
    '.spec.containers[0].volumeMounts[] | select(.mountPath == $path) | .name')" || { failed; return; }

  # Check that mount names are not empty
  [ -n "$config_mount_name" ] || { failed; return; }
  [ -n "$secret_mount_name" ] || { failed; return; }

  # Verify config volumeMount points to the expected ConfigMap
  echo "$pod_json" | jq -e --arg name "$config_mount_name" --arg cm "$cm_name" \
    '.spec.volumes[] | select(.name == $name) | .configMap.name == $cm' > /dev/null || { failed; return; }

  # Verify secret volumeMount points to the expected Secret
  echo "$pod_json" | jq -e --arg name "$secret_mount_name" --arg secret "$secret_name" \
    '.spec.volumes[] | select(.name == $name) | .secret.secretName == $secret' > /dev/null || { failed; return; }

  solved
}

verify_task8() {
  TASK_NUMBER="8"

  local namespace="files"
  local env_configmap_name="config-env"
  local env_secret_name="secret-env"
  local file_configmap_name="config-file"
  local file_secret_name="secret-file"
  local pod_name="app-pod"
  local image="httpd:2.4"
  local config_env_file="t8config.env"
  local env_key1="environment"
  local env_key2="title"
  local secret_env_file="t8secret.env"
  local secret_key1="user"
  local secret_key2="password"
  local config_file_key="t8config.database"
  local secret_file_key="t8secret.database"
  local config_mount_path="/etc/database/config.properties"
  local secret_mount_path="/etc/database/secret.properties"

  # Expected values from files (replace these with actual expected values)
  local expected_env_environment expected_env_title
  expected_env_environment=$(grep "^${env_key1}=" "./$config_env_file" | cut -d '=' -f2-)
  expected_env_title=$(grep "^${env_key2}=" "./$config_env_file" | cut -d '=' -f2-)

  local expected_secret_user expected_secret_password
  expected_secret_user=$(grep "^${secret_key1}=" "./$secret_env_file" | cut -d '=' -f2-)
  expected_secret_password=$(grep "^${secret_key2}=" "./$secret_env_file" | cut -d '=' -f2-)


  # 1. Verify configmap config-env
  local cm_env_json
  cm_env_json="$(kubectl get configmap "$env_configmap_name" -n "$namespace" -o json 2>/dev/null)" || { failed; return; }
  jq -e --arg k "$env_key1" --arg v "$expected_env_environment" '.data[$k] == $v' <<<"$cm_env_json" > /dev/null || { failed; return; }
  jq -e --arg k "$env_key2" --arg v "$expected_env_title" '.data[$k] == $v' <<<"$cm_env_json" > /dev/null || { failed; return; }

  # 2. Verify configmap config-file
  local cm_file_json
  cm_file_json="$(kubectl get configmap "$file_configmap_name" -n "$namespace" -o jsonpath='{.data.t8config\.database}' 2>/dev/null)" || { failed; return; }
  diff "./$config_file_key" <(echo "$cm_file_json") 2>/dev/null || { failed; return; }

  # 3. Verify secret secret-env
  local secret_env_json
  secret_env_json="$(kubectl get secret "$env_secret_name" -n "$namespace" -o json 2>/dev/null)" || { failed; return; }
  local user_decoded
  user_decoded="$(jq -r --arg k "$secret_key1" '.data[$k]' <<<"$secret_env_json" | base64 -d)" || { failed; return; }
  [ "$user_decoded" = "$expected_secret_user" ] || { failed; return; }
  local password_decoded
  password_decoded="$(jq -r --arg k "$secret_key2" '.data[$k]' <<<"$secret_env_json" | base64 -d)" || { failed; return; }
  [ "$password_decoded" = "$expected_secret_password" ] || { failed; return; }

  # 4. Verify secret secret-file
  local secret_file_json
  # secret_file_json="$(kubectl get secret "$secret_file" -n "$namespace" -o json 2>/dev/null)" || { failed; return; }
  secret_file_json="$(kubectl get secret "$file_secret_name" -n "$namespace" -o jsonpath='{.data.t8secret\.database}' 2>/dev/null)" || { failed; return; }
  local secret_file_decoded
  secret_file_decoded="$(echo "$secret_file_json" | base64 -d)" || { failed; return; }
  diff "./$secret_file_key" <(echo "$secret_file_decoded") 2>/dev/null || { failed; return; }

  # 5. Verify pod exists and get as json
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || { failed; return; }

  # 6. Verify pod image
  jq -e --arg img "$image" '.spec.containers[0].image == $img' <<<"$pod_json" > /dev/null || { failed; return; }

  # 7. Verify env variables from configmap and secret
  jq -e --arg name "APP_ENV" --arg cm "$env_configmap_name" --arg key "$env_key1" \
    '.spec.containers[0].env[] | select(.name == $name and .valueFrom.configMapKeyRef.name == $cm and .valueFrom.configMapKeyRef.key == $key)' <<<"$pod_json" > /dev/null || { failed; return; }
  jq -e --arg name "APP_TITLE" --arg cm "$env_configmap_name" --arg key "$env_key2" \
    '.spec.containers[0].env[] | select(.name == $name and .valueFrom.configMapKeyRef.name == $cm and .valueFrom.configMapKeyRef.key == $key)' <<<"$pod_json" > /dev/null || { failed; return; }
  jq -e --arg name "APP_USER" --arg sec "$env_secret_name" --arg key "$secret_key1" \
    '.spec.containers[0].env[] | select(.name == $name and .valueFrom.secretKeyRef.name == $sec and .valueFrom.secretKeyRef.key == $key)' <<<"$pod_json" > /dev/null || { failed; return; }
  jq -e --arg name "APP_PASSWORD" --arg sec "$env_secret_name" --arg key "$secret_key2" \
    '.spec.containers[0].env[] | select(.name == $name and .valueFrom.secretKeyRef.name == $sec and .valueFrom.secretKeyRef.key == $key)' <<<"$pod_json" > /dev/null || { failed; return; }

  # 8. Verify volumeMounts and volumes for configmap and secret
  local config_volume
  config_volume="$(jq -r '.spec.containers[0].volumeMounts[] | select(.mountPath == "/etc/database/config.properties") | .name' <<<"$pod_json")" || { failed; return; }
  jq -e --arg vol "$config_volume" --arg cm "$file_configmap_name" --arg key "$config_file_key" \
    '.spec.volumes[] | select(.name == $vol and .configMap.name == $cm)' <<<"$pod_json" > /dev/null || { failed; return; }

  local secret_volume
  secret_volume="$(jq -r '.spec.containers[0].volumeMounts[] | select(.mountPath == "/etc/database/secret.properties") | .name' <<<"$pod_json")" || { failed; return; }
  jq -e --arg vol "$secret_volume" --arg sec "$file_secret_name" --arg key "$secret_file_key" \
    '.spec.volumes[] | select(.name == $vol and .secret.secretName == $sec)' <<<"$pod_json" > /dev/null || { failed; return; }

  # 9. Verify in-container env and files (exec into pod)
  local env_val
  env_val="$(kubectl exec -n "$namespace" "$pod_name" -- printenv APP_ENV)" || { failed; return; }
  [ "$env_val" = "$expected_env_environment" ] || { failed; return; }
  env_val="$(kubectl exec -n "$namespace" "$pod_name" -- printenv APP_TITLE)" || { failed; return; }
  [ "$env_val" = "$expected_env_title" ] || { failed; return; }
  env_val="$(kubectl exec -n "$namespace" "$pod_name" -- printenv APP_USER)" || { failed; return; }
  [ "$env_val" = "$expected_secret_user" ] || { failed; return; }
  env_val="$(kubectl exec -n "$namespace" "$pod_name" -- printenv APP_PASSWORD)" || { failed; return; }
  [ "$env_val" = "$expected_secret_password" ] || { failed; return; }
  local file_content
  file_content="$(kubectl exec -n "$namespace" "$pod_name" -- cat "$config_mount_path")" || { failed; return; }
  [ "$file_content" = "$(cat ./${config_file_key})"  ] || { failed; return; }
  file_content="$(kubectl exec -n "$namespace" "$pod_name" -- cat "$secret_mount_path")" || { failed; return; }
  [ "$file_content" = "$(cat ./${secret_file_key})" ] || { failed; return; }

  solved
  return
}

verify_task9() {
  TASK_NUMBER="9"

  local namespace="default"
  local cm_name="immutable-config"
  local expected_cm_key="APP_ENV"
  local expected_cm_value="staging"
  local cm_json

  # Verify ConfigMap exists and get its json
  cm_json="$(kubectl get configmap "$cm_name" -n "$namespace" -o json 2>/dev/null)" || { failed; return; }

  # Verify ConfigMap contains expected data
  echo "$cm_json" | jq -e --arg key "$expected_cm_key" --arg val "$expected_cm_value" \
    '.data[$key] == $val' > /dev/null || { failed; return; }

  # Verify ConfigMap is immutable
  echo "$cm_json" | jq -e '.immutable == true' > /dev/null || { failed; return; }

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
exit 0
