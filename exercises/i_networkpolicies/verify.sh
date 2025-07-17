#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

# shellcheck disable=SC2317
verify_task1() {
  TASK_NUMBER="1"
  local expected_deploy_name="internal-api"
  local expected_namespace="internal"
  local expected_image="nginx:1.25"
  local expected_container_port=80
  local expected_service_name="internal-api-svc"
  local expected_service_type="ClusterIP"
  local expected_service_port=8080
  local expected_service_target_port=80
  local expected_np_name="allow-from-admin"
  local expected_np_label_value="admin"
  local expected_ns_selector_key="kubernetes.io/metadata.name"
  local expected_ns_selector_value="internal"

  # Check if the deployment exists and uses the correct image
  debug "Checking if deployment \"$expected_deploy_name\" exists in namespace \"$expected_namespace\" and uses image \"$expected_image\"."
  local deploy_json
  deploy_json="$(kubectl get deployment "$expected_deploy_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get deployment \"$expected_deploy_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local deploy_image
  deploy_image="$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null)" || {
    debug "Failed to extract image from deployment JSON."
    failed
    return
  }
  if [ "$deploy_image" != "$expected_image" ]; then
    debug "Deployment image mismatch: expected \"$expected_image\", found \"$deploy_image\"."
    failed
    return
  fi

  # Check if the container exposes the correct port
  debug "Checking if deployment container exposes port $expected_container_port."
  local deploy_container_port
  deploy_container_port="$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].ports[0].containerPort' 2>/dev/null)" || {
    debug "Failed to extract containerPort from deployment JSON."
    failed
    return
  }
  if [ "$deploy_container_port" != "$expected_container_port" ]; then
    debug "Deployment containerPort mismatch: expected \"$expected_container_port\", found \"$deploy_container_port\"."
    failed
    return
  fi

  # Extract deployment pod template labels
  debug "Extracting deployment pod template labels."
  local deploy_labels_json
  deploy_labels_json="$(echo "$deploy_json" | jq -c '.spec.template.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract deployment pod template labels."
    failed
    return
  }

  # Check if the service exists and is of correct type
  debug "Checking if service \"$expected_service_name\" exists in namespace \"$expected_namespace\" and is of type \"$expected_service_type\"."
  local svc_json
  svc_json="$(kubectl get service "$expected_service_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get service \"$expected_service_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local svc_type
  svc_type="$(echo "$svc_json" | jq -r '.spec.type' 2>/dev/null)" || {
    debug "Failed to extract service type from service JSON."
    failed
    return
  }
  if [ "$svc_type" != "$expected_service_type" ]; then
    debug "Service type mismatch: expected \"$expected_service_type\", found \"$svc_type\"."
    failed
    return
  fi

  # Check if the service exposes the correct port and targetPort
  debug "Checking if service \"$expected_service_name\" exposes port $expected_service_port and targetPort $expected_service_target_port."
  local svc_port
  svc_port="$(echo "$svc_json" | jq -r '.spec.ports[0].port' 2>/dev/null)" || {
    debug "Failed to extract service port from service JSON."
    failed
    return
  }
  local svc_target_port
  svc_target_port="$(echo "$svc_json" | jq -r '.spec.ports[0].targetPort' 2>/dev/null)" || {
    debug "Failed to extract service targetPort from service JSON."
    failed
    return
  }
  if [ "$svc_port" != "$expected_service_port" ]; then
    debug "Service port mismatch: expected \"$expected_service_port\", found \"$svc_port\"."
    failed
    return
  fi
  if [ "$svc_target_port" != "$expected_service_target_port" ]; then
    debug "Service targetPort mismatch: expected \"$expected_service_target_port\", found \"$svc_target_port\"."
    failed
    return
  fi

  # Check if the service selector matches the deployment pod template labels
  debug "Checking if service selector matches deployment pod template labels."
  local svc_selector_json
  svc_selector_json="$(echo "$svc_json" | jq -c '.spec.selector' 2>/dev/null)" || {
    debug "Failed to extract service selector from service JSON."
    failed
    return
  }
  if [ "$svc_selector_json" != "$deploy_labels_json" ]; then
    debug "Service selector does not match deployment pod template labels. Expected: $deploy_labels_json, Found: $svc_selector_json"
    failed
    return
  fi

  # Check if the NetworkPolicy exists
  debug "Checking if NetworkPolicy \"$expected_np_name\" exists in namespace \"$expected_namespace\"."
  local np_json
  np_json="$(kubectl get networkpolicy "$expected_np_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get NetworkPolicy \"$expected_np_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the NetworkPolicy selects the correct pods (using the same selector as the service/deployment)
  debug "Checking if NetworkPolicy podSelector matches deployment pod template labels."
  local np_pod_selector_json
  np_pod_selector_json="$(echo "$np_json" | jq -c '.spec.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy JSON."
    failed
    return
  }
  if [ "$np_pod_selector_json" != "$deploy_labels_json" ]; then
    debug "NetworkPolicy podSelector does not match deployment pod template labels. Expected: $deploy_labels_json, Found: $np_pod_selector_json"
    failed
    return
  fi

  # Check that there is exactly one entry in .spec.ingress[0].from
  debug "Checking that there is exactly one entry in NetworkPolicy ingress.from."
  local from_entries_count
  from_entries_count="$(echo "$np_json" | jq '.spec.ingress[0].from | length' 2>/dev/null)" || {
    debug "Failed to count ingress.from entries in NetworkPolicy JSON."
    failed
    return
  }
  if [ "$from_entries_count" -ne 1 ]; then
    debug "NetworkPolicy ingress.from should have exactly one entry, found $from_entries_count."
    failed
    return
  fi

  # Check the single entry for correct podSelector and optional namespaceSelector
  debug "Checking the single ingress.from entry for correct podSelector and optional namespaceSelector."
  local entry
  entry="$(echo "$np_json" | jq '.spec.ingress[0].from[0]' 2>/dev/null)" || {
    debug "Failed to extract the single ingress.from entry."
    failed
    return
  }
  local has_pod_selector
  has_pod_selector="$(echo "$entry" | jq 'has("podSelector")' 2>/dev/null)"
  if [ "$has_pod_selector" != "true" ]; then
    debug "The single ingress.from entry must have a podSelector."
    failed
    return
  fi
  local role_value
  role_value="$(echo "$entry" | jq -r '.podSelector.matchLabels.role // empty' 2>/dev/null)"
  if [ "$role_value" != "$expected_np_label_value" ]; then
    debug "podSelector.matchLabels.role mismatch: expected \"$expected_np_label_value\", found \"$role_value\"."
    failed
    return
  fi
  local has_ns_selector
  has_ns_selector="$(echo "$entry" | jq 'has("namespaceSelector")' 2>/dev/null)"
  if [ "$has_ns_selector" = "true" ]; then
    local ns_value
    ns_value="$(echo "$entry" | jq -r ".namespaceSelector.matchLabels[\"$expected_ns_selector_key\"] // empty" 2>/dev/null)"
    if [ "$ns_value" != "$expected_ns_selector_value" ]; then
      debug "namespaceSelector.matchLabels.$expected_ns_selector_key mismatch: expected \"$expected_ns_selector_value\", found \"$ns_value\"."
      failed
      return
    fi
  fi

  debug "All checks passed for Task $TASK_NUMBER. Service and NetworkPolicy are strictly and correctly configured for IP whitelisting."
  solved
  return
}

# shellcheck disable=SC2317
verify_task2() {
  TASK_NUMBER="2"
  local expected_namespace="net-policy"
  local expected_frontend_pod="frontend"
  local expected_frontend_image="nginx:1.25"
  local expected_backend_pod="backend"
  local expected_backend_image="hashicorp/http-echo:1.0"
  local expected_backend_args='["-text=backend"]'
  local expected_backend_port=5678
  local expected_service_name="backend-svc"
  local expected_service_port=8080
  local expected_np_name="deny-all"

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" -o json >/dev/null 2>&1 || {
    debug "Namespace \"$expected_namespace\" does not exist."
    failed
    return
  }

  # Check if the frontend pod exists and uses the correct image
  debug "Checking if frontend pod \"$expected_frontend_pod\" exists and uses image \"$expected_frontend_image\"."
  local frontend_pod_json
  frontend_pod_json="$(kubectl get pod "$expected_frontend_pod" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get frontend pod \"$expected_frontend_pod\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local frontend_image
  frontend_image="$(echo "$frontend_pod_json" | jq -r '.spec.containers[0].image' 2>/dev/null)" || {
    debug "Failed to extract image from frontend pod JSON."
    failed
    return
  }
  if [ "$frontend_image" != "$expected_frontend_image" ]; then
    debug "Frontend pod image mismatch: expected \"$expected_frontend_image\", found \"$frontend_image\"."
    failed
    return
  fi

  # Check if the backend pod exists and uses the correct image, args, and port
  debug "Checking if backend pod \"$expected_backend_pod\" exists and uses image \"$expected_backend_image\"."
  local backend_pod_json
  backend_pod_json="$(kubectl get pod "$expected_backend_pod" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get backend pod \"$expected_backend_pod\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local backend_image
  backend_image="$(echo "$backend_pod_json" | jq -r '.spec.containers[0].image' 2>/dev/null)" || {
    debug "Failed to extract image from backend pod JSON."
    failed
    return
  }
  if [ "$backend_image" != "$expected_backend_image" ]; then
    debug "Backend pod image mismatch: expected \"$expected_backend_image\", found \"$backend_image\"."
    failed
    return
  fi

  debug "Checking backend pod args."
  local backend_args
  backend_args="$(echo "$backend_pod_json" | jq -c '.spec.containers[0].args' 2>/dev/null)" || {
    debug "Failed to extract args from backend pod JSON."
    failed
    return
  }
  if [ "$backend_args" != "$expected_backend_args" ]; then
    debug "Backend pod args mismatch: expected $expected_backend_args, found $backend_args."
    failed
    return
  fi

  debug "Checking backend pod containerPort."
  local backend_port
  backend_port="$(echo "$backend_pod_json" | jq -r '.spec.containers[0].ports[0].containerPort' 2>/dev/null)" || {
    debug "Failed to extract containerPort from backend pod JSON."
    failed
    return
  }
  if [ "$backend_port" != "$expected_backend_port" ]; then
    debug "Backend pod containerPort mismatch: expected $expected_backend_port, found $backend_port."
    failed
    return
  fi

  # Check if the backend service exists and is of correct type and port
  debug "Checking if service \"$expected_service_name\" exists and exposes port $expected_service_port."
  local svc_json
  svc_json="$(kubectl get service "$expected_service_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get service \"$expected_service_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local svc_port
  svc_port="$(echo "$svc_json" | jq -r '.spec.ports[0].port' 2>/dev/null)" || {
    debug "Failed to extract service port from service JSON."
    failed
    return
  }
  if [ "$svc_port" != "$expected_service_port" ]; then
    debug "Service port mismatch: expected $expected_service_port, found $svc_port."
    failed
    return
  fi

  # Check if the NetworkPolicy exists
  debug "Checking if NetworkPolicy \"$expected_np_name\" exists."
  local np_json
  np_json="$(kubectl get networkpolicy "$expected_np_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get NetworkPolicy \"$expected_np_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check that the NetworkPolicy targets the backend pod
  debug "Checking if NetworkPolicy podSelector matches backend pod labels."
  local backend_labels_json
  backend_labels_json="$(echo "$backend_pod_json" | jq -c '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract backend pod labels."
    failed
    return
  }
  local np_pod_selector_json
  np_pod_selector_json="$(echo "$np_json" | jq -c '.spec.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy JSON."
    failed
    return
  }
  # The backend pod must match the podSelector
  local selector_match
  selector_match="$(echo "$backend_labels_json" | jq --argjson sel "$np_pod_selector_json" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
    debug "Failed to compare backend pod labels with NetworkPolicy podSelector."
    failed
    return
  }
  if [ "$selector_match" != "true" ]; then
    debug "NetworkPolicy podSelector does not match backend pod labels. Selector: $np_pod_selector_json, Pod labels: $backend_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy denies all ingress except from frontend
  debug "Checking that NetworkPolicy denies all ingress except from frontend."
  local ingress_count
  ingress_count="$(echo "$np_json" | jq '.spec.ingress | length' 2>/dev/null)" || {
    debug "Failed to count ingress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$ingress_count" -ne 1 ]; then
    debug "NetworkPolicy should have exactly one ingress rule, found $ingress_count."
    failed
    return
  fi

  local from_count
  from_count="$(echo "$np_json" | jq '.spec.ingress[0].from | length' 2>/dev/null)" || {
    debug "Failed to count from entries in NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$from_count" -ne 1 ]; then
    debug "NetworkPolicy ingress rule should have exactly one from entry, found $from_count."
    failed
    return
  fi

  local from_entry
  from_entry="$(echo "$np_json" | jq '.spec.ingress[0].from[0]' 2>/dev/null)" || {
    debug "Failed to extract from entry from NetworkPolicy ingress rule."
    failed
    return
  }
  local has_pod_selector
  has_pod_selector="$(echo "$from_entry" | jq 'has("podSelector")' 2>/dev/null)"
  if [ "$has_pod_selector" != "true" ]; then
    debug "NetworkPolicy ingress.from entry must have a podSelector."
    failed
    return
  fi

  # The podSelector must match the frontend pod's labels
  local frontend_labels_json
  frontend_labels_json="$(echo "$frontend_pod_json" | jq -c '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract frontend pod labels."
    failed
    return
  }
  local from_pod_selector_json
  from_pod_selector_json="$(echo "$from_entry" | jq -c '.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy ingress.from entry."
    failed
    return
  }
  local frontend_selector_match
  frontend_selector_match="$(echo "$frontend_labels_json" | jq --argjson sel "$from_pod_selector_json" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
    debug "Failed to compare frontend pod labels with NetworkPolicy ingress.from podSelector."
    failed
    return
  }
  if [ "$frontend_selector_match" != "true" ]; then
    debug "NetworkPolicy ingress.from podSelector does not match frontend pod labels. Selector: $from_pod_selector_json, Pod labels: $frontend_labels_json"
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. NetworkPolicy correctly restricts ingress to backend pod from frontend pod only."
  solved
  return
}

# shellcheck disable=SC2317
verify_task3() {
  TASK_NUMBER="3"
  local expected_namespace="netpol-demo1"
  local expected_backend_pod="backend"
  local expected_backend_label_key="app"
  local expected_backend_label_value="backend"
  local expected_backend_port=80
  local expected_frontend_pod="frontend"
  local expected_frontend_label_key="role"
  local expected_frontend_label_value="frontend"
  local expected_np_name="allow-frontend"

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" >/dev/null 2>&1 || {
    debug "Namespace \"$expected_namespace\" does not exist."
    failed
    return
  }

  # Check if the backend pod exists and has the correct label
  debug "Checking if backend pod \"$expected_backend_pod\" exists and has label \"$expected_backend_label_key: $expected_backend_label_value\"."
  local backend_pod_json
  backend_pod_json="$(kubectl get pod "$expected_backend_pod" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get backend pod \"$expected_backend_pod\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local backend_label_value
  backend_label_value="$(echo "$backend_pod_json" | jq -r ".metadata.labels[\"$expected_backend_label_key\"]" 2>/dev/null)" || {
    debug "Failed to extract backend pod label \"$expected_backend_label_key\"."
    failed
    return
  }
  if [ "$backend_label_value" != "$expected_backend_label_value" ]; then
    debug "Backend pod label mismatch: expected \"$expected_backend_label_key: $expected_backend_label_value\", found \"$expected_backend_label_key: $backend_label_value\"."
    failed
    return
  fi

  # Check if the backend pod exposes the correct port
  debug "Checking if backend pod exposes containerPort $expected_backend_port."
  local backend_port
  backend_port="$(echo "$backend_pod_json" | jq -r '.spec.containers[0].ports[0].containerPort' 2>/dev/null)" || {
    debug "Failed to extract backend pod containerPort."
    failed
    return
  }
  if [ "$backend_port" != "$expected_backend_port" ]; then
    debug "Backend pod containerPort mismatch: expected $expected_backend_port, found $backend_port."
    failed
    return
  fi

  # Check if the frontend pod exists and has the correct label
  debug "Checking if frontend pod \"$expected_frontend_pod\" exists and has label \"$expected_frontend_label_key: $expected_frontend_label_value\"."
  local frontend_pod_json
  frontend_pod_json="$(kubectl get pod "$expected_frontend_pod" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get frontend pod \"$expected_frontend_pod\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local frontend_label_value
  frontend_label_value="$(echo "$frontend_pod_json" | jq -r ".metadata.labels[\"$expected_frontend_label_key\"]" 2>/dev/null)" || {
    debug "Failed to extract frontend pod label \"$expected_frontend_label_key\"."
    failed
    return
  }
  if [ "$frontend_label_value" != "$expected_frontend_label_value" ]; then
    debug "Frontend pod label mismatch: expected \"$expected_frontend_label_key: $expected_frontend_label_value\", found \"$expected_frontend_label_key: $frontend_label_value\"."
    failed
    return
  fi

  # Check if the NetworkPolicy exists
  debug "Checking if NetworkPolicy \"$expected_np_name\" exists."
  local np_json
  np_json="$(kubectl get networkpolicy "$expected_np_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get NetworkPolicy \"$expected_np_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check that the NetworkPolicy targets the backend pod
  debug "Checking if NetworkPolicy podSelector matches backend pod labels."
  local backend_labels_json
  backend_labels_json="$(echo "$backend_pod_json" | jq -c '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract backend pod labels."
    failed
    return
  }
  local np_pod_selector_json
  np_pod_selector_json="$(echo "$np_json" | jq -c '.spec.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy JSON."
    failed
    return
  }
  local selector_match
  selector_match="$(echo "$backend_labels_json" | jq --argjson sel "$np_pod_selector_json" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
    debug "Failed to compare backend pod labels with NetworkPolicy podSelector."
    failed
    return
  }
  if [ "$selector_match" != "true" ]; then
    debug "NetworkPolicy podSelector does not match backend pod labels. Selector: $np_pod_selector_json, Pod labels: $backend_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy allows ingress only from pods with label role=frontend on port 80
  debug "Checking that NetworkPolicy allows ingress only from pods with label \"$expected_frontend_label_key: $expected_frontend_label_value\" on port $expected_backend_port."
  local ingress_count
  ingress_count="$(echo "$np_json" | jq '.spec.ingress | length' 2>/dev/null)" || {
    debug "Failed to count ingress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$ingress_count" -ne 1 ]; then
    debug "NetworkPolicy should have exactly one ingress rule, found $ingress_count."
    failed
    return
  fi

  local from_count
  from_count="$(echo "$np_json" | jq '.spec.ingress[0].from | length' 2>/dev/null)" || {
    debug "Failed to count from entries in NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$from_count" -ne 1 ]; then
    debug "NetworkPolicy ingress rule should have exactly one from entry, found $from_count."
    failed
    return
  fi

  local from_entry
  from_entry="$(echo "$np_json" | jq '.spec.ingress[0].from[0]' 2>/dev/null)" || {
    debug "Failed to extract from entry from NetworkPolicy ingress rule."
    failed
    return
  }
  local has_pod_selector
  has_pod_selector="$(echo "$from_entry" | jq 'has("podSelector")' 2>/dev/null)"
  if [ "$has_pod_selector" != "true" ]; then
    debug "NetworkPolicy ingress.from entry must have a podSelector."
    failed
    return
  fi

  # The podSelector must match the frontend pod's labels
  local frontend_labels_json
  frontend_labels_json="$(echo "$frontend_pod_json" | jq -c '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract frontend pod labels."
    failed
    return
  }
  local from_pod_selector_json
  from_pod_selector_json="$(echo "$from_entry" | jq -c '.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy ingress.from entry."
    failed
    return
  }
  local frontend_selector_match
  frontend_selector_match="$(echo "$frontend_labels_json" | jq --argjson sel "$from_pod_selector_json" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
    debug "Failed to compare frontend pod labels with NetworkPolicy ingress.from podSelector."
    failed
    return
  }
  if [ "$frontend_selector_match" != "true" ]; then
    debug "NetworkPolicy ingress.from podSelector does not match frontend pod labels. Selector: $from_pod_selector_json, Pod labels: $frontend_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy only allows port 80
  debug "Checking that NetworkPolicy only allows port $expected_backend_port."
  local ports_count
  ports_count="$(echo "$np_json" | jq '.spec.ingress[0].ports | length' 2>/dev/null)" || {
    debug "Failed to count ports in NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$ports_count" -ne 1 ]; then
    debug "NetworkPolicy ingress rule should have exactly one port entry, found $ports_count."
    failed
    return
  fi
  local port_value
  port_value="$(echo "$np_json" | jq -r '.spec.ingress[0].ports[0].port' 2>/dev/null)" || {
    debug "Failed to extract port from NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$port_value" != "$expected_backend_port" ]; then
    debug "NetworkPolicy ingress rule port mismatch: expected $expected_backend_port, found $port_value."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. NetworkPolicy correctly restricts backend access to pods with label \"$expected_frontend_label_key: $expected_frontend_label_value\" on port $expected_backend_port."
  solved
  return
}

# shellcheck disable=SC2317
verify_task4() {
  TASK_NUMBER="4"
  local expected_namespace="netpol-demo2"
  local expected_pod_name="isolated"
  local expected_np_name="deny-all-except-dns"
  local expected_dns_port=53
  local expected_dns_protocol="UDP"

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" >/dev/null 2>&1 || {
    debug "Namespace \"$expected_namespace\" does not exist."
    failed
    return
  }

  # Check if the isolated pod exists
  debug "Checking if pod \"$expected_pod_name\" exists."
  local pod_json
  pod_json="$(kubectl get pod "$expected_pod_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get pod \"$expected_pod_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the NetworkPolicy exists
  debug "Checking if NetworkPolicy \"$expected_np_name\" exists."
  local np_json
  np_json="$(kubectl get networkpolicy "$expected_np_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get NetworkPolicy \"$expected_np_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check that the NetworkPolicy targets the isolated pod or all pods (podSelector: {})
  debug "Checking if NetworkPolicy podSelector targets the isolated pod or all pods."
  local np_pod_selector
  np_pod_selector="$(echo "$np_json" | jq '.spec.podSelector' 2>/dev/null)" || {
    debug "Failed to extract podSelector from NetworkPolicy JSON."
    failed
    return
  }
  local np_pod_selector_matchlabels
  np_pod_selector_matchlabels="$(echo "$np_json" | jq '.spec.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy JSON."
    failed
    return
  }
  local pod_labels_json
  pod_labels_json="$(echo "$pod_json" | jq '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract isolated pod labels."
    failed
    return
  }
  # Accept if podSelector is {} or podSelector.matchLabels is {} or matches pod's labels
  local selector_ok="false"
  if [ "$np_pod_selector" = "{}" ] || [ "$np_pod_selector_matchlabels" = "{}" ]; then
    selector_ok="true"
  else
    # Compare matchLabels with pod labels
    local selector_match
    selector_match="$(echo "$pod_labels_json" | jq --argjson sel "$np_pod_selector_matchlabels" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
      debug "Failed to compare isolated pod labels with NetworkPolicy podSelector."
      failed
      return
    }
    if [ "$selector_match" = "true" ]; then
      selector_ok="true"
    fi
  fi
  if [ "$selector_ok" != "true" ]; then
    debug "NetworkPolicy podSelector does not target the isolated pod or all pods. podSelector: $np_pod_selector, pod labels: $pod_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy denies all ingress (no ingress rules)
  debug "Checking that NetworkPolicy denies all ingress."
  local ingress_exists
  ingress_exists="$(echo "$np_json" | jq '.spec | has("ingress")' 2>/dev/null)" || {
    debug "Failed to check for ingress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$ingress_exists" = "true" ]; then
    local ingress_length
    ingress_length="$(echo "$np_json" | jq '.spec.ingress | length' 2>/dev/null)"
    if [ "$ingress_length" -ne 0 ]; then
      debug "NetworkPolicy should deny all ingress (no ingress rules), but found $ingress_length ingress rule(s)."
      failed
      return
    fi
  fi

  # Check that the NetworkPolicy allows only egress to DNS (UDP port 53)
  debug "Checking that NetworkPolicy allows only egress to DNS (UDP port 53)."
  local egress_exists
  egress_exists="$(echo "$np_json" | jq '.spec | has("egress")' 2>/dev/null)" || {
    debug "Failed to check for egress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$egress_exists" != "true" ]; then
    debug "NetworkPolicy must have an egress rule allowing DNS."
    failed
    return
  fi
  local egress_length
  egress_length="$(echo "$np_json" | jq '.spec.egress | length' 2>/dev/null)" || {
    debug "Failed to count egress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$egress_length" -ne 1 ]; then
    debug "NetworkPolicy should have exactly one egress rule, found $egress_length."
    failed
    return
  fi

  local egress_ports_length
  egress_ports_length="$(echo "$np_json" | jq '.spec.egress[0].ports | length' 2>/dev/null)" || {
    debug "Failed to count ports in NetworkPolicy egress rule."
    failed
    return
  }
  if [ "$egress_ports_length" -ne 1 ]; then
    debug "NetworkPolicy egress rule should have exactly one port entry, found $egress_ports_length."
    failed
    return
  fi

  local egress_port
  egress_port="$(echo "$np_json" | jq -r '.spec.egress[0].ports[0].port' 2>/dev/null)" || {
    debug "Failed to extract port from NetworkPolicy egress rule."
    failed
    return
  }
  if [ "$egress_port" != "$expected_dns_port" ]; then
    debug "NetworkPolicy egress rule port mismatch: expected $expected_dns_port, found $egress_port."
    failed
    return
  fi

  local egress_protocol
  egress_protocol="$(echo "$np_json" | jq -r '.spec.egress[0].ports[0].protocol' 2>/dev/null)" || {
    debug "Failed to extract protocol from NetworkPolicy egress rule."
    failed
    return
  }
  if [ "$egress_protocol" != "$expected_dns_protocol" ]; then
    debug "NetworkPolicy egress rule protocol mismatch: expected $expected_dns_protocol, found $egress_protocol."
    failed
    return
  fi

  # Check that policyTypes includes both Ingress and Egress
  debug "Checking that NetworkPolicy policyTypes includes both Ingress and Egress."
  local policy_types
  policy_types="$(echo "$np_json" | jq -c '.spec.policyTypes' 2>/dev/null)" || {
    debug "Failed to extract policyTypes from NetworkPolicy."
    failed
    return
  }
  local has_ingress
  has_ingress="$(echo "$policy_types" | jq 'index("Ingress")' 2>/dev/null)"
  local has_egress
  has_egress="$(echo "$policy_types" | jq 'index("Egress")' 2>/dev/null)"
  if [ "$has_ingress" = "null" ] || [ "$has_egress" = "null" ]; then
    debug "NetworkPolicy policyTypes must include both \"Ingress\" and \"Egress\". Found: $policy_types"
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. NetworkPolicy correctly denies all ingress and egress except DNS."
  solved
  return
}

# shellcheck disable=SC2317
verify_task5() {
  TASK_NUMBER="5"
  local expected_namespace="netpol-demo3"
  local expected_pod_name="api-server"
  local expected_pod_label_key="app"
  local expected_pod_label_value="api-server"
  local expected_np_name="allow-from-trusted-ns"
  local expected_trusted_ns="trusted-ns"
  local expected_ns_selector_key="kubernetes.io/metadata.name"

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" >/dev/null 2>&1 || {
    debug "Namespace \"$expected_namespace\" does not exist."
    failed
    return
  }

  # Check if the api-server pod exists and has the correct label
  debug "Checking if pod \"$expected_pod_name\" exists and has label \"$expected_pod_label_key: $expected_pod_label_value\"."
  local pod_json
  pod_json="$(kubectl get pod "$expected_pod_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get pod \"$expected_pod_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local pod_label_value
  pod_label_value="$(echo "$pod_json" | jq -r ".metadata.labels[\"$expected_pod_label_key\"]" 2>/dev/null)" || {
    debug "Failed to extract pod label \"$expected_pod_label_key\"."
    failed
    return
  }
  if [ "$pod_label_value" != "$expected_pod_label_value" ]; then
    debug "Pod label mismatch: expected \"$expected_pod_label_key: $expected_pod_label_value\", found \"$expected_pod_label_key: $pod_label_value\"."
    failed
    return
  fi

  # Check if the NetworkPolicy exists
  debug "Checking if NetworkPolicy \"$expected_np_name\" exists."
  local np_json
  np_json="$(kubectl get networkpolicy "$expected_np_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get NetworkPolicy \"$expected_np_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check that the NetworkPolicy targets the api-server pod
  debug "Checking if NetworkPolicy podSelector matches api-server pod labels."
  local pod_labels_json
  pod_labels_json="$(echo "$pod_json" | jq -c '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract api-server pod labels."
    failed
    return
  }
  local np_pod_selector_json
  np_pod_selector_json="$(echo "$np_json" | jq -c '.spec.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy JSON."
    failed
    return
  }
  local selector_match
  selector_match="$(echo "$pod_labels_json" | jq --argjson sel "$np_pod_selector_json" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
    debug "Failed to compare api-server pod labels with NetworkPolicy podSelector."
    failed
    return
  }
  if [ "$selector_match" != "true" ]; then
    debug "NetworkPolicy podSelector does not match api-server pod labels. Selector: $np_pod_selector_json, Pod labels: $pod_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy allows ingress only from pods in the trusted-ns namespace
  debug "Checking that NetworkPolicy allows ingress only from pods in namespace \"$expected_trusted_ns\"."
  local ingress_count
  ingress_count="$(echo "$np_json" | jq '.spec.ingress | length' 2>/dev/null)" || {
    debug "Failed to count ingress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$ingress_count" -ne 1 ]; then
    debug "NetworkPolicy should have exactly one ingress rule, found $ingress_count."
    failed
    return
  fi

  local from_count
  from_count="$(echo "$np_json" | jq '.spec.ingress[0].from | length' 2>/dev/null)" || {
    debug "Failed to count from entries in NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$from_count" -ne 1 ]; then
    debug "NetworkPolicy ingress rule should have exactly one from entry, found $from_count."
    failed
    return
  fi

  local from_entry
  from_entry="$(echo "$np_json" | jq '.spec.ingress[0].from[0]' 2>/dev/null)" || {
    debug "Failed to extract from entry from NetworkPolicy ingress rule."
    failed
    return
  }
  local has_ns_selector
  has_ns_selector="$(echo "$from_entry" | jq 'has("namespaceSelector")' 2>/dev/null)"
  if [ "$has_ns_selector" != "true" ]; then
    debug "NetworkPolicy ingress.from entry must have a namespaceSelector."
    failed
    return
  fi

  local ns_selector_value
  ns_selector_value="$(echo "$from_entry" | jq -r ".namespaceSelector.matchLabels[\"$expected_ns_selector_key\"] // empty" 2>/dev/null)"
  if [ "$ns_selector_value" != "$expected_trusted_ns" ]; then
    debug "namespaceSelector.matchLabels.$expected_ns_selector_key mismatch: expected \"$expected_trusted_ns\", found \"$ns_selector_value\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. NetworkPolicy correctly allows ingress only from pods in namespace \"$expected_trusted_ns\"."
  solved
  return
}

# shellcheck disable=SC2317
verify_task6() {
  TASK_NUMBER="6"
  local expected_namespace="netpol-demo4"
  local expected_web_pod="web"
  local expected_web_label_key="app"
  local expected_web_label_value="web"
  local expected_client_pod="client"
  local expected_client_label_key="access"
  local expected_client_label_value="web"
  local expected_np_name="http-only-from-client"
  local expected_port=80

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" >/dev/null 2>&1 || {
    debug "Namespace \"$expected_namespace\" does not exist."
    failed
    return
  }

  # Check if the web pod exists and has the correct label
  debug "Checking if web pod \"$expected_web_pod\" exists and has label \"$expected_web_label_key: $expected_web_label_value\"."
  local web_pod_json
  web_pod_json="$(kubectl get pod "$expected_web_pod" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get web pod \"$expected_web_pod\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local web_label_value
  web_label_value="$(echo "$web_pod_json" | jq -r ".metadata.labels[\"$expected_web_label_key\"]" 2>/dev/null)" || {
    debug "Failed to extract web pod label \"$expected_web_label_key\"."
    failed
    return
  }
  if [ "$web_label_value" != "$expected_web_label_value" ]; then
    debug "Web pod label mismatch: expected \"$expected_web_label_key: $expected_web_label_value\", found \"$expected_web_label_key: $web_label_value\"."
    failed
    return
  fi

  # Check if the client pod exists and has the correct label
  debug "Checking if client pod \"$expected_client_pod\" exists and has label \"$expected_client_label_key: $expected_client_label_value\"."
  local client_pod_json
  client_pod_json="$(kubectl get pod "$expected_client_pod" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get client pod \"$expected_client_pod\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local client_label_value
  client_label_value="$(echo "$client_pod_json" | jq -r ".metadata.labels[\"$expected_client_label_key\"]" 2>/dev/null)" || {
    debug "Failed to extract client pod label \"$expected_client_label_key\"."
    failed
    return
  }
  if [ "$client_label_value" != "$expected_client_label_value" ]; then
    debug "Client pod label mismatch: expected \"$expected_client_label_key: $expected_client_label_value\", found \"$expected_client_label_key: $client_label_value\"."
    failed
    return
  fi

  # Check if the NetworkPolicy exists
  debug "Checking if NetworkPolicy \"$expected_np_name\" exists."
  local np_json
  np_json="$(kubectl get networkpolicy "$expected_np_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get NetworkPolicy \"$expected_np_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check that the NetworkPolicy targets the web pod
  debug "Checking if NetworkPolicy podSelector matches web pod labels."
  local web_labels_json
  web_labels_json="$(echo "$web_pod_json" | jq -c '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract web pod labels."
    failed
    return
  }
  local np_pod_selector_json
  np_pod_selector_json="$(echo "$np_json" | jq -c '.spec.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy JSON."
    failed
    return
  }
  local selector_match
  selector_match="$(echo "$web_labels_json" | jq --argjson sel "$np_pod_selector_json" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
    debug "Failed to compare web pod labels with NetworkPolicy podSelector."
    failed
    return
  }
  if [ "$selector_match" != "true" ]; then
    debug "NetworkPolicy podSelector does not match web pod labels. Selector: $np_pod_selector_json, Pod labels: $web_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy allows ingress only from pods with label access=web on port 80
  debug "Checking that NetworkPolicy allows ingress only from pods with label \"$expected_client_label_key: $expected_client_label_value\" on port $expected_port."
  local ingress_count
  ingress_count="$(echo "$np_json" | jq '.spec.ingress | length' 2>/dev/null)" || {
    debug "Failed to count ingress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$ingress_count" -ne 1 ]; then
    debug "NetworkPolicy should have exactly one ingress rule, found $ingress_count."
    failed
    return
  fi

  local from_count
  from_count="$(echo "$np_json" | jq '.spec.ingress[0].from | length' 2>/dev/null)" || {
    debug "Failed to count from entries in NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$from_count" -ne 1 ]; then
    debug "NetworkPolicy ingress rule should have exactly one from entry, found $from_count."
    failed
    return
  fi

  local from_entry
  from_entry="$(echo "$np_json" | jq '.spec.ingress[0].from[0]' 2>/dev/null)" || {
    debug "Failed to extract from entry from NetworkPolicy ingress rule."
    failed
    return
  }
  local has_pod_selector
  has_pod_selector="$(echo "$from_entry" | jq 'has("podSelector")' 2>/dev/null)"
  if [ "$has_pod_selector" != "true" ]; then
    debug "NetworkPolicy ingress.from entry must have a podSelector."
    failed
    return
  fi

  # The podSelector must match the client pod's labels
  local client_labels_json
  client_labels_json="$(echo "$client_pod_json" | jq -c '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract client pod labels."
    failed
    return
  }
  local from_pod_selector_json
  from_pod_selector_json="$(echo "$from_entry" | jq -c '.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy ingress.from entry."
    failed
    return
  }
  local client_selector_match
  client_selector_match="$(echo "$client_labels_json" | jq --argjson sel "$from_pod_selector_json" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
    debug "Failed to compare client pod labels with NetworkPolicy ingress.from podSelector."
    failed
    return
  }
  if [ "$client_selector_match" != "true" ]; then
    debug "NetworkPolicy ingress.from podSelector does not match client pod labels. Selector: $from_pod_selector_json, Pod labels: $client_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy only allows port 80
  debug "Checking that NetworkPolicy only allows port $expected_port."
  local ports_count
  ports_count="$(echo "$np_json" | jq '.spec.ingress[0].ports | length' 2>/dev/null)" || {
    debug "Failed to count ports in NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$ports_count" -ne 1 ]; then
    debug "NetworkPolicy ingress rule should have exactly one port entry, found $ports_count."
    failed
    return
  fi
  local port_value
  port_value="$(echo "$np_json" | jq -r '.spec.ingress[0].ports[0].port' 2>/dev/null)" || {
    debug "Failed to extract port from NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$port_value" != "$expected_port" ]; then
    debug "NetworkPolicy ingress rule port mismatch: expected $expected_port, found $port_value."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. NetworkPolicy correctly allows only HTTP traffic from pods with label \"$expected_client_label_key: $expected_client_label_value\"."
  solved
  return
}

# shellcheck disable=SC2317
verify_task7() {
  TASK_NUMBER="7"
  local expected_namespace="netpol-demo5"
  local expected_pod_name="egress-pod"
  local expected_np_name="allow-egress-external"
  local expected_ip_block="8.8.8.8/32"
  local expected_port=53
  local expected_protocol="TCP"

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" >/dev/null 2>&1 || {
    debug "Namespace \"$expected_namespace\" does not exist."
    failed
    return
  }

  # Check if the egress-pod exists
  debug "Checking if pod \"$expected_pod_name\" exists."
  local pod_json
  pod_json="$(kubectl get pod "$expected_pod_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get pod \"$expected_pod_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the NetworkPolicy exists
  debug "Checking if NetworkPolicy \"$expected_np_name\" exists."
  local np_json
  np_json="$(kubectl get networkpolicy "$expected_np_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get NetworkPolicy \"$expected_np_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check that the NetworkPolicy targets the egress-pod or all pods (podSelector: {})
  debug "Checking if NetworkPolicy podSelector targets the egress-pod or all pods."
  local np_pod_selector
  np_pod_selector="$(echo "$np_json" | jq '.spec.podSelector' 2>/dev/null)" || {
    debug "Failed to extract podSelector from NetworkPolicy JSON."
    failed
    return
  }
  local np_pod_selector_matchlabels
  np_pod_selector_matchlabels="$(echo "$np_json" | jq '.spec.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy JSON."
    failed
    return
  }
  local pod_labels_json
  pod_labels_json="$(echo "$pod_json" | jq '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract egress-pod labels."
    failed
    return
  }
  local selector_ok="false"
  if [ "$np_pod_selector" = "{}" ] || [ "$np_pod_selector_matchlabels" = "{}" ]; then
    selector_ok="true"
  else
    local selector_match
    selector_match="$(echo "$pod_labels_json" | jq --argjson sel "$np_pod_selector_matchlabels" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
      debug "Failed to compare egress-pod labels with NetworkPolicy podSelector."
      failed
      return
    }
    if [ "$selector_match" = "true" ]; then
      selector_ok="true"
    fi
  fi
  if [ "$selector_ok" != "true" ]; then
    debug "NetworkPolicy podSelector does not target the egress-pod or all pods. podSelector: $np_pod_selector, pod labels: $pod_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy allows only egress to 8.8.8.8/32 on TCP port 53
  debug "Checking that NetworkPolicy allows only egress to $expected_ip_block on $expected_protocol port $expected_port."
  local egress_exists
  egress_exists="$(echo "$np_json" | jq '.spec | has("egress")' 2>/dev/null)" || {
    debug "Failed to check for egress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$egress_exists" != "true" ]; then
    debug "NetworkPolicy must have an egress rule."
    failed
    return
  fi
  local egress_length
  egress_length="$(echo "$np_json" | jq '.spec.egress | length' 2>/dev/null)" || {
    debug "Failed to count egress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$egress_length" -ne 1 ]; then
    debug "NetworkPolicy should have exactly one egress rule, found $egress_length."
    failed
    return
  fi

  local to_count
  to_count="$(echo "$np_json" | jq '.spec.egress[0].to | length' 2>/dev/null)" || {
    debug "Failed to count to entries in NetworkPolicy egress rule."
    failed
    return
  }
  if [ "$to_count" -ne 1 ]; then
    debug "NetworkPolicy egress rule should have exactly one to entry, found $to_count."
    failed
    return
  fi

  local to_entry
  to_entry="$(echo "$np_json" | jq '.spec.egress[0].to[0]' 2>/dev/null)" || {
    debug "Failed to extract to entry from NetworkPolicy egress rule."
    failed
    return
  }
  local has_ip_block
  has_ip_block="$(echo "$to_entry" | jq 'has("ipBlock")' 2>/dev/null)"
  if [ "$has_ip_block" != "true" ]; then
    debug "NetworkPolicy egress.to entry must have an ipBlock."
    failed
    return
  fi

  local ip_block_cidr
  ip_block_cidr="$(echo "$to_entry" | jq -r '.ipBlock.cidr' 2>/dev/null)" || {
    debug "Failed to extract ipBlock.cidr from NetworkPolicy egress.to entry."
    failed
    return
  }
  if [ "$ip_block_cidr" != "$expected_ip_block" ]; then
    debug "NetworkPolicy egress.to ipBlock.cidr mismatch: expected $expected_ip_block, found $ip_block_cidr."
    failed
    return
  fi

  local egress_ports_length
  egress_ports_length="$(echo "$np_json" | jq '.spec.egress[0].ports | length' 2>/dev/null)" || {
    debug "Failed to count ports in NetworkPolicy egress rule."
    failed
    return
  }
  if [ "$egress_ports_length" -ne 1 ]; then
    debug "NetworkPolicy egress rule should have exactly one port entry, found $egress_ports_length."
    failed
    return
  fi

  local egress_port
  egress_port="$(echo "$np_json" | jq -r '.spec.egress[0].ports[0].port' 2>/dev/null)" || {
    debug "Failed to extract port from NetworkPolicy egress rule."
    failed
    return
  }
  if [ "$egress_port" != "$expected_port" ]; then
    debug "NetworkPolicy egress rule port mismatch: expected $expected_port, found $egress_port."
    failed
    return
  fi

  local egress_protocol
  egress_protocol="$(echo "$np_json" | jq -r '.spec.egress[0].ports[0].protocol' 2>/dev/null)" || {
    debug "Failed to extract protocol from NetworkPolicy egress rule."
    failed
    return
  }
  if [ "$egress_protocol" != "$expected_protocol" ]; then
    debug "NetworkPolicy egress rule protocol mismatch: expected $expected_protocol, found $egress_protocol."
    failed
    return
  fi

  # Check that policyTypes includes Egress
  debug "Checking that NetworkPolicy policyTypes includes Egress."
  local policy_types
  policy_types="$(echo "$np_json" | jq -c '.spec.policyTypes' 2>/dev/null)" || {
    debug "Failed to extract policyTypes from NetworkPolicy."
    failed
    return
  }
  local has_egress
  has_egress="$(echo "$policy_types" | jq 'index("Egress")' 2>/dev/null)"
  if [ "$has_egress" = "null" ]; then
    debug "NetworkPolicy policyTypes must include \"Egress\". Found: $policy_types"
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. NetworkPolicy correctly allows egress only to $expected_ip_block on $expected_protocol port $expected_port."
  solved
  return
}

# shellcheck disable=SC2034
VERIFY_TASK_FUNCTIONS=(
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
)
run_verification VERIFY_TASK_FUNCTIONS "$@"

exit 0
