#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

verify_task1() {
  TASK_NUMBER="1"

  # Local Variables
  local namespace="default"
  local job_name="simple-job"
  local expected_image="busybox:1.28"
  local expected_command='echo "Hello CKAD"'

  # Verify that the Job exists in the default namespace
  local job_exists
  job_exists=$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)
  if [[ -z $job_exists ]]; then
    failed
    return
  fi

  # Verify the Job image
  local job_image
  job_image=$(echo "$job_exists" | jq -r '.spec.template.spec.containers[0].image')
  if [[ "$job_image" != "$expected_image" ]]; then
    failed
    return
  fi

  # Verify the Job command
  local job_command
  job_command=$(echo "$job_exists" | jq -r '.spec.template.spec.containers[0].command | join(" ")')
  if [[ ! "$job_command" == *"$expected_command" ]]; then
    failed
    return
  fi

  # Verify that the Job's status shows successful completion
  local completions
  completions=$(echo "$job_exists" | jq -r '.status.succeeded // 0')
  if [[ "$completions" -lt 1 ]]; then
    failed
    return
  fi

  # If all checks pass
  solved
}

verify_task2() {
  # Non-local task number variable
  TASK_NUMBER="2"

  # Local declaration of variables
  local job_name="parallel-job"
  local namespace="processor"
  local expected_parallelism=3
  local expected_completions=6
  local expected_image="busybox:1.28"
  local expected_command='echo "Processing data"'

  # Verify Job exists
  local job
  job=$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)
  if [[ -z "$job" ]]; then
    failed
    return
  fi

  # Validate parallelism
  local parallelism
  parallelism=$(echo "$job" | jq '.spec.parallelism // 0')
  if [[ "$parallelism" -ne "$expected_parallelism" ]]; then
    failed
    return
  fi

  # Validate completions
  local completions
  completions=$(echo "$job" | jq '.spec.completions // 0')
  if [[ "$completions" -ne "$expected_completions" ]]; then
    failed
    return
  fi

  # Validate container image
  local image
  image=$(echo "$job" | jq -r '.spec.template.spec.containers[0].image // ""')
  if [[ "$image" != "$expected_image" ]]; then
    failed
    return
  fi

  # Validate container command
  local command
  command=$(echo "$job" | jq -r '.spec.template.spec.containers[0].command | join(" ")')
  if [[ ! "$command" == *"$expected_command" ]]; then
    failed
    return
  fi

  # Verify `restartPolicy` is set to Never
  local restart_policy
  restart_policy=$(echo "$job" | jq -r '.spec.template.spec.restartPolicy // ""')
  if [[ "$restart_policy" != "Never" ]]; then
    failed
    return
  fi

  # Check if all pods are successfully completed
  local succeeded_pods
  succeeded_pods=$(kubectl get pods -n "$namespace" -l "job-name=$job_name" -o json | jq '[.items[] | select(.status.phase == "Succeeded")] | length')
  if [[ "$succeeded_pods" -ne "$expected_completions" ]]; then
    failed
    return
  fi

  # All checks passed
  solved
}

function verify_task3() {
  TASK_NUMBER="3"

  # Local declaration of variables
  local namespace="cleanup"
  local job_name="ttl-cleanup-job"
  local expected_image="alpine:3.22"
  local job_yaml_file="t3job.yaml"
  local expected_ttl="20"

  # Check if the Job YAML file exists
  if [[ ! -f "$job_yaml_file" ]]; then
    failed
    return
  fi

  # Validate that the Job YAML definition includes the correct TTL and Image
  local job_ttl
  job_ttl=$(grep "ttlSecondsAfterFinished:" "$job_yaml_file" | awk '{print $2}')
  if [[ "$job_ttl" != "$expected_ttl" ]]; then
    failed
    return
  fi

  # Validate container image
  local job_image
  job_image=$(grep "image:" "$job_yaml_file" | awk '{print $3}')
  if [[ "$job_image" != "$expected_image" ]]; then
    failed
    return
  fi

  # Check Kubernetes events for Job creation and completion
  local pod_events
  pod_events=$(kubectl get events -n "$namespace" --field-selector involvedObject.name="$job_name" -o json | jq -r '.items[].reason')
  if [[ ! "$pod_events" == *"SuccessfulCreate"* || ! "$pod_events" == *"Completed"* ]]; then
    failed
    return
  fi

  # Check the Job is not present in Kubernetes anymore
  local job_not_found
  job_not_found=$(kubectl get jobs -n "$namespace" "$job_name" 2>&1)
  if [[ ! "$job_not_found" == "Error from server (NotFound):"* ]]; then
    failed
    return
  fi

  solved
}

verify_task4() {
  TASK_NUMBER="4"

  # Local declaration of variables
  local job_name="failure-job"
  local namespace="default"
  local expected_image="busybox:1.28"
  local expected_command='ls /nonexistent-directory'

  # Check if the Job exists
  local job
  job=$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)
  if [[ -z "$job" ]]; then
    failed
    return
  fi

  # Validate container image
  local image
  image=$(echo "$job" | jq -r '.spec.template.spec.containers[0].image // ""')
  if [[ "$image" != "$expected_image" ]]; then
    failed
    return
  fi

  # Validate container command
  local command
  command=$(echo "$job" | jq -r '.spec.template.spec.containers[0].command | join(" ")')
  if [[ ! "$command" == *"$expected_command" ]]; then
    failed
    return
  fi

  # Verify the backoffLimit is set to 2
  local backoff_limit
  backoff_limit=$(echo "$job" | jq '.spec.backoffLimit // empty')
  if [[ "$backoff_limit" -ne 2 ]]; then
    failed
    return
  fi

  # Check if the Job failed
  local failed_pods
  failed_pods=$(kubectl get pods -n "$namespace" -o json | jq "[.items[] | select(.metadata.ownerReferences[].name == \"$job_name\" and .status.phase == \"Failed\")] | length")
  if [[ "$failed_pods" -lt 1 ]]; then
    failed
    return
  fi

  # Ensure no new Runs or infinite retries
  local job_failed_condition
  job_failed_condition=$(echo "$job" | jq -r '.status.conditions[]? | select(.type == "Failed") | .status // empty')
  if [[ "$job_failed_condition" != "True" ]]; then
    failed
    return
  fi

  solved
  return
}

verify_task5() {
  TASK_NUMBER="5"

  # Define local variables
  local namespace="scheduled"
  local cronjob_name="scheduled-job"
  local expected_image="busybox:1.28"
  local schedule="*/1 * * * *"
  local min_success_count=2

  # Check if the CronJob exists in the namespace
  local cronjob
  cronjob=$(kubectl get cronjob "${cronjob_name}" -n "${namespace}" -o json 2>/dev/null)
  if [ -z "${cronjob}" ]; then
    failed
    return
  fi

  # Verify the image version
  local actual_image
  actual_image=$(echo "${cronjob}" | jq -r '.spec.jobTemplate.spec.template.spec.containers[0].image')
  if [ "${actual_image}" != "${expected_image}" ]; then
    failed
    return
  fi

  # Verify the schedule
  local actual_schedule
  actual_schedule=$(echo "${cronjob}" | jq -r '.spec.schedule')
  if [ "${actual_schedule}" != "${schedule}" ]; then
    failed
    return
  fi

  # Verify at least 2 successful runs
  local job_successful_runs
  job_successful_runs=$(kubectl get cronjob "${cronjob_name}" -n "${namespace}" -o json | jq -r '.status.successfulJobsHistoryLimit // 0')
  if [ "${job_successful_runs}" -gt "${min_success_count}" ]; then
    failed
    return
  fi

  solved
  return
}

verify_task6() {
  TASK_NUMBER="6"

  # Define local variables
  local job_name="indexed-completion-job"
  local namespace="default"
  local expected_command="This is task \$JOB_COMPLETION_INDEX"

  # Verify Namespace
  if ! kubectl get namespace "$namespace" &> /dev/null; then
    failed
    return
  fi

  # Verify Job configuration
  local job_yaml
  job_yaml=$(kubectl get job "$job_name" -n "$namespace" -o json 2> /dev/null)
  if [[ -z "$job_yaml" ]]; then
    failed
    return
  fi

  # Verify Job completions
  local completions
  completions=$(echo "$job_yaml" | jq -r '.spec.completions')
  if [[ "$completions" -ne 3 ]]; then
    failed
    return
  fi

  # Verify completionMode
  local completion_mode
  completion_mode=$(echo "$job_yaml" | jq -r '.spec.completionMode')
  if [[ "$completion_mode" != "Indexed" ]]; then
    failed
    return
  fi

  # Verify Pod template spec
  local template_spec
  template_spec=$(echo "$job_yaml" | jq -r '.spec.template.spec')

  # Verify Container Image
  local image
  image=$(echo "$template_spec" | jq -r '.containers[0].image')
  if [[ "$image" != "busybox:1.28" ]]; then
    failed
    return
  fi

  # Verify Container Command
  local command
  command=$(echo "$template_spec" | jq -r '.containers[0].command | join(" ")')
  if [[ ! "$command" == *"\"$expected_command\"" ]]; then
    failed
    return
  fi

  # Verify Restart Policy
  local restart_policy
  restart_policy=$(echo "$template_spec" | jq -r '.restartPolicy')
  if [[ "$restart_policy" != "Never" ]]; then
    failed
    return
  fi

  # Verify Logs for Each Pod
  local pods
  pods=$(kubectl get pods -n "$namespace" -l job-name="$job_name" -o json)
  local pod_count
  pod_count=$(echo "$pods" | jq '.items | length')
  if [[ "$pod_count" -ne 3 ]]; then
    failed
    return
  fi

  for i in $(seq 0 2); do
    local pod_name
    pod_name=$(echo "$pods" | jq -r ".items[$i].metadata.name")
    if [[ -z "$pod_name" ]]; then
      failed
      return
    fi

    local log_contents
    log_contents=$(kubectl logs -n "$namespace" "$pod_name" 2> /dev/null)
    if [[ "$log_contents" != "This is task $i" ]]; then
      failed
      return
    fi
  done

  # If all checks are passed
  solved
  return
}

verify_task7() {
  TASK_NUMBER="7"

  local job_name="retry-policy-job"
  local namespace="default"


  # Verify the Job exists and is named `retry-policy-job` in the namespace `default`
  local job_output
  job_output=$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)
  if [[ -z "$job_output" ]]; then
    failed
    return
  fi

  # Verify the `backoffLimit` is set to 3
  local backoff_limit
  backoff_limit=$(echo "$job_output" | jq -r '.spec.backoffLimit')
  if [[ "$backoff_limit" != "3" ]]; then
    failed
    return
  fi

  # Verify the PodFailurePolicy configuration
  local pod_failure_policy
  pod_failure_policy=$(echo "$job_output" | jq -r '.spec.podFailurePolicy')

  local action
  action=$(echo "$pod_failure_policy" | jq -r '.rules[0].action')
  if [[ "$action" != "FailJob" ]]; then
    failed
    return
  fi

  local operator
  operator=$(echo "$pod_failure_policy" | jq -r '.rules[0].onExitCodes.operator')
  if [[ "$operator" != "NotIn" ]]; then
    failed
    return
  fi

  local exit_code_value
  exit_code_value=$(echo "$pod_failure_policy" | jq -r '.rules[0].onExitCodes.values[0]')
  if [[ "$exit_code_value" != "2" ]]; then
    failed
    return
  fi

  # Verify the Job template configuration (image, container name, command, etc.)
  local container_image
  container_image=$(echo "$job_output" | jq -r '.spec.template.spec.containers[0].image')
  if [[ "$container_image" != "busybox:1.28" ]]; then
    failed
    return
  fi

  local command
  command=$(echo "$job_output" | jq -r '.spec.template.spec.containers[0].command | join(" ")')
  if [[ ! "$command" == *"cat /nonexistent-file" ]]; then
    failed
    return
  fi

  local restart_policy
  restart_policy=$(echo "$job_output" | jq -r '.spec.template.spec.restartPolicy')
  if [[ "$restart_policy" != "Never" ]]; then
    failed
    return
  fi

  # If all checks pass, call solved
  solved
  return
}

verify_task8() {
  TASK_NUMBER="8"

  # Local variable declarations
  local job_name="resource-limited-job"
  local namespace="default"
  local expected_image="busybox:1.28"
  local expected_command='echo "Resources handled"'
  local memory_request="32Mi"
  local memory_limit="64Mi"
  local cpu_request="250m"
  local cpu_limit="500m"

  # Fetch the Job details in JSON format
  local job_json
  job_json=$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)
  if [[ -z "$job_json" ]]; then
    failed
    return
  fi

  # Verify the Job's container image
  local actual_image
  actual_image=$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].image')
  if [[ "$actual_image" != "$expected_image" ]]; then
    failed
    return
  fi

  # Verify Container Command
  local actual_command
  actual_command=$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].command | join(" ")')
  if [[ ! "$actual_command" == *"$expected_command" ]]; then
    failed
    return
  fi

  # Verify resource requests
  local actual_memory_request
  actual_memory_request=$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].resources.requests.memory')
  if [[ "$actual_memory_request" != "$memory_request" ]]; then
    failed
    return
  fi

  local actual_cpu_request
  actual_cpu_request=$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].resources.requests.cpu')
  if [[ "$actual_cpu_request" != "$cpu_request" ]]; then
    failed
    return
  fi

  # Verify resource limits
  local actual_memory_limit
  actual_memory_limit=$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].resources.limits.memory')
  if [[ "$actual_memory_limit" != "$memory_limit" ]]; then
    failed
    return
  fi

  local actual_cpu_limit
  actual_cpu_limit=$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].resources.limits.cpu')
  if [[ "$actual_cpu_limit" != "$cpu_limit" ]]; then
    failed
    return
  fi

  # Verify Job status and ensure completion
  local job_status
  job_status=$(echo "$job_json" | jq -r '.status.conditions[] | select(.type=="Complete" and .status=="True")')
  if [[ -z "$job_status" ]]; then
    failed
    return
  fi

  # Verification successful
  solved
  return
}

verify_task9() {
  TASK_NUMBER="9"

  local job_name="label-job"
  local namespace="default"
  local expected_image="busybox:1.28"
  local expected_label_key="purpose"
  local expected_label_value="testing"

  # Check if the Job exists in the default namespace
  local job_check
  job_check=$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)
  if [ -z "$job_check" ]; then
    failed
    return
  fi

  # Verify the image used in the Job
  local actual_image
  actual_image=$(echo "$job_check" | jq -r '.spec.template.spec.containers[0].image')
  if [ "$actual_image" != "$expected_image" ]; then
    failed
    return
  fi

  # Verify the custom label exists in the Pod template
  local label_value
  label_value=$(echo "$job_check" | jq -r ".spec.template.metadata.labels[\"$expected_label_key\"]")
  if [ "$label_value" != "$expected_label_value" ]; then
    failed
    return
  fi

  # Verify that the Pod created by the Job includes the custom label
  local pod_name
  pod_name=$(kubectl get pod -n "${namespace}" -l "job-name=${job_name}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -z "${pod_name}" ]; then
    failed
    return
  fi

  local pod_label_value
  pod_label_value=$(kubectl get pod "$pod_name" -n "$namespace" -o json | jq -r ".metadata.labels[\"$expected_label_key\"]")
  if [ "$pod_label_value" != "$expected_label_value" ]; then
    failed
    return
  fi

  solved
  return
}

verify_task10() {
  TASK_NUMBER="10"

  local namespace="affinity"
  local job_name="affinity-job"
  local expected_image="busybox:1.28"
  local required_label_key="app"
  local required_label_value="web-server"
  local topology_key="kubernetes.io/hostname"

  # Check if the Job exists in the given namespace
  if ! kubectl get job "${job_name}" -n "${namespace}" &> /dev/null; then
    failed
    return
  fi

  # Verify if the Job's configuration matches the requirements
  local job_json
  job_json=$(kubectl get job "${job_name}" -n "${namespace}" -o json)

  # Verify image name and version
  local image
  image=$(echo "${job_json}" | jq -r '.spec.template.spec.containers[0].image')
  if [ "${image}" != "${expected_image}" ]; then
    failed
    return
  fi

  # Verify podAffinity configuration
  local pod_affinity
  pod_affinity=$(echo "${job_json}" | jq '.spec.template.spec.affinity.podAffinity.requiredDuringSchedulingIgnoredDuringExecution')
  if [ "${pod_affinity}" == "null" ]; then
    failed
    return
  fi

  # Check the required affinity conditions (labelSelector and topologyKey)
  local affinity_label_key
  local affinity_label_operator
  local affinity_label_value
  affinity_label_key=$(echo "${pod_affinity}" | jq -r '.[0].labelSelector.matchExpressions[0].key')
  affinity_label_operator=$(echo "${pod_affinity}" | jq -r '.[0].labelSelector.matchExpressions[0].operator')
  affinity_label_value=$(echo "${pod_affinity}" | jq -r '.[0].labelSelector.matchExpressions[0].values[0]')
  local affinity_topology_key
  affinity_topology_key=$(echo "${pod_affinity}" | jq -r '.[0].topologyKey')

  if [ "${affinity_label_key}" != "${required_label_key}" ] ||
     [ "${affinity_label_operator}" != "In" ] ||
     [ "${affinity_label_value}" != "${required_label_value}" ] ||
     [ "${affinity_topology_key}" != "${topology_key}" ]; then
    failed
    return
  fi

  # Check if any Pod of the Job has been created and ensure it meets the affinity rules
  local pod_name
  pod_name=$(kubectl get pod -n "${namespace}" -l "job-name=${job_name}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -z "${pod_name}" ]; then
    failed
    return
  fi

  # Verify if the Pod is scheduled on a node with the required label `app=web-server`
  local pod_node
  pod_node=$(kubectl get pod "${pod_name}" -n "${namespace}" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
  if [ -z "${pod_node}" ]; then
    failed
    return
  fi

  local web_server_pods
  web_server_pods=$(kubectl get pod -A -l "app=${required_label_value}" -o jsonpath='{.items[*].spec.nodeName}')
  if [[ ! "${web_server_pods}" =~ ${pod_node} ]]; then
    failed
    return
  fi

  # If all checks pass, mark the task as solved
  solved
  return
}

function verify_task11() {
  TASK_NUMBER="11"

  # Local Variable Definitions
  local job_name="long-job"
  local namespace="default"
  local expected_image="busybox:1.28"
  local expected_command="for i in \$(seq 1 60); do echo \"Running step \$i\"; sleep 1; done"
  local restart_policy="Never"

  # Verify the Job exists
  local job_exists
  job_exists=$(kubectl get job $job_name -n $namespace -o json 2>/dev/null)
  if [[ -z "$job_exists" ]]; then
    failed
    return
  fi

  # Verify the Job's specification
  local job_image
  job_image=$(echo "$job_exists" | jq -r '.spec.template.spec.containers[0].image')
  if [[ "$job_image" != "$expected_image" ]]; then
    failed
    return
  fi

  local job_command
  job_command=$(echo "$job_exists" | jq -r '.spec.template.spec.containers[0].command | join(" ")')
  if [[ ! "$job_command" == *"$expected_command" ]]; then
    failed
    return
  fi

  local job_restart_policy
  job_restart_policy=$(echo "$job_exists" | jq -r '.spec.template.spec.restartPolicy')
  if [[ "$job_restart_policy" != "$restart_policy" ]]; then
    failed
    return
  fi

  # Check if the Job completed successfully
  local job_status
  job_status=$(echo "$job_exists" | jq -r '.status.succeeded')
  if [[ "$job_status" != "1" ]]; then
    failed
    return
  fi

  # Verify the logs of the Job's Pod
  local pod_name
  pod_name=$(kubectl get pods -n "$namespace" -l job-name="$job_name" -o json | jq -r '.items[0].metadata.name')
  if [[ -z "$pod_name" ]]; then
    failed
    return
  fi

  local pod_logs
  pod_logs=$(kubectl logs "$pod_name" -n "$namespace" 2>/dev/null)
  if [[ -z "$pod_logs" ]]; then
    failed
    return
  fi

  for i in $(seq 1 60); do
    if ! echo "$pod_logs" | grep -q "Running step $i"; then
      failed
      return
    fi
  done

  # If all checks pass
  solved
  return
}

verify_task12() {
  TASK_NUMBER="12"

  # Local variables
  local namespace="default"
  local cronjob_name="print-date"
  local expected_image="busybox:1.28"
  local expected_command="/bin/sh -c"
  local expected_args="echo \"Current date: \$(date)\""
  local expected_restart_policy="Never"
  local expected_schedule="*/5 * * * *"

  # Retrieve the CronJob details
  local cronjob
  cronjob=$(kubectl get cronjob $cronjob_name -n $namespace -o json 2>/dev/null)

  # Check if the CronJob exists
  if [[ -z "$cronjob" ]]; then
    failed
    return
  fi

  # Verify the schedule
  local schedule
  schedule=$(echo "$cronjob" | jq -r '.spec.schedule // empty')
  if [[ "$schedule" != "$expected_schedule" ]]; then
    failed
    return
  fi

  # Verify the image
  local image
  image=$(echo "$cronjob" | jq -r '.spec.jobTemplate.spec.template.spec.containers[0].image // empty')
  if [[ "$image" != "$expected_image" ]]; then
    failed
    return
  fi

  # Verify the command
  local command
  command=$(echo "$cronjob" | jq -r '.spec.jobTemplate.spec.template.spec.containers[0].command | join(" ")')
  if [[ "$command" != "$expected_command" ]]; then
    failed
    return
  fi

  # Verify the args
  local args
  args=$(echo "$cronjob" | jq -r '.spec.jobTemplate.spec.template.spec.containers[0].args | join(" ")')
  if [[ "$args" != "$expected_args" ]]; then
    failed
    return
  fi

  # Verify the restart policy
  local restart_policy
  restart_policy=$(echo "$cronjob" | jq -r '.spec.jobTemplate.spec.template.spec.restartPolicy // empty')
  if [[ "$restart_policy" != "$expected_restart_policy" ]]; then
    failed
    return
  fi

  # Call `solved` if all checks passed
  solved
  return
}

verify_task13() {
  TASK_NUMBER="13"
  local namespace="sidecar"
  local job_name="sidecar-job"
  local container_name="sidecar-job"
  local init_container_name="log-forwarder"
  local main_image="alpine:3.22"
  local init_image="busybox:1.28"
  local shared_volume_name="data"
  local main_command='echo "app log" > /opt/logs.txt'
  local init_command="tail -F /opt/logs.txt"

  # Verify the namespace exists
  if ! kubectl get ns "${namespace}" &>/dev/null; then
    failed
    return
  fi

  # Verify the Job exists
  if ! kubectl get job "${job_name}" -n "${namespace}" -o json | jq . &>/dev/null; then
    failed
    return
  fi

  # Verify the Job specification
  local job_spec
  job_spec=$(kubectl get job "${job_name}" -n "${namespace}" -o json)

  # Check if the job has the correct container(s)
  local containers
  containers=$(echo "${job_spec}" | jq -r '.spec.template.spec.containers[].name')
  if ! echo "${containers}" | grep -q "${container_name}"; then
    failed
    return
  fi

  # Verify main container image and command
  local main_image_actual
  main_image_actual=$(echo "${job_spec}" | jq -r '.spec.template.spec.containers[] | select(.name=="'"${container_name}"'").image')
  if [ "${main_image_actual}" != "${main_image}" ]; then
    failed
    return
  fi

  local main_command_actual
  main_command_actual=$(echo "${job_spec}" | jq -r '.spec.template.spec.containers[] | select(.name=="'"${container_name}"'").command | join(" ")')
  if [[ ! "${main_command_actual}" == *"${main_command}" ]]; then
    failed
    return
  fi

  # Verify initContainer image, command, and restart policy
  local init_container
  init_container=$(echo "${job_spec}" | jq -r '.spec.template.spec.initContainers[] | select(.name=="'"${init_container_name}"'")')

  local init_image_actual
  init_image_actual=$(echo "${init_container}" | jq -r '.image')
  if [ "${init_image_actual}" != "${init_image}" ]; then
    failed
    return
  fi

  local init_command_actual
  init_command_actual=$(echo "${init_container}" | jq -r '.command | join(" ")')
  if [[ ! "${init_command_actual}" == *"${init_command}" ]]; then
    failed
    return
  fi

  local init_restart_policy_actual
  init_restart_policy_actual=$(echo "${job_spec}" | jq -r '.spec.template.spec.initContainers[] | select(.name=="'"${init_container_name}"'").restartPolicy')
  if [ "${init_restart_policy_actual}" != "Always" ]; then
    failed
    return
  fi

  # Verify shared volume configuration
  local volume
  volume=$(echo "${job_spec}" | jq -r '.spec.template.spec.volumes[] | select(.name=="'"${shared_volume_name}"'")')
  if [ "$(echo "${volume}" | jq -r '.emptyDir | objects | length')" != "0" ]; then
    failed
    return
  fi

  # Verify volume mounts in the main container
  local main_volume_mount
  main_volume_mount=$(echo "${job_spec}" | jq -r '.spec.template.spec.containers[] | select(.name=="'"${container_name}"'").volumeMounts[] | select(.name=="'"${shared_volume_name}"'").mountPath')
  if [ "${main_volume_mount}" != "/opt" ]; then
    failed
    return
  fi

  # Verify volume mounts in the initContainer
  local init_volume_mount
  init_volume_mount=$(echo "${job_spec}" | jq -r '.spec.template.spec.initContainers[] | select(.name=="'"${init_container_name}"'").volumeMounts[] | select(.name=="'"${shared_volume_name}"'").mountPath')
  if [ "${init_volume_mount}" != "/opt" ]; then
    failed
    return
  fi

  # Ensure the Job has the correct restartPolicy
  local restart_policy_actual
  restart_policy_actual=$(echo "${job_spec}" | jq -r '.spec.template.spec.restartPolicy')
  if [ "${restart_policy_actual}" != "Never" ]; then
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
exit 0
