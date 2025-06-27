#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

verify_task1() {
  TASK_NUMBER="1"
  local namespace="ckad"

  if kubectl get ns "$namespace" &> /dev/null; then
    solved
  else
    failed
  fi
}

verify_task2() {
  TASK_NUMBER="2"
  local namespace="foo"

  if [ ! -f ./"$namespace".yaml ]; then
    failed
    return
  fi

  if kubectl get ns "$namespace" &> /dev/null; then
    solved
  else
    failed
  fi
  return
}

verify_task3() {
  TASK_NUMBER="3"
  local namespace="foo"

  local annotation_hello
  annotation_hello=$(kubectl get ns ${namespace} -o jsonpath="{.metadata.annotations.hello}" 2> /dev/null)
  if [ "${annotation_hello}" != "world" ]; then
    failed
    return
  fi

  local annotation_learning
  annotation_learning=$(kubectl get ns ${namespace} -o jsonpath="{.metadata.annotations.learning}" 2> /dev/null)
  if [ "${annotation_learning}" == "kubernetes" ]; then
    failed
    return
  fi

  solved
  return
}

verify_task4() {
  TASK_NUMBER="4"
  local namespace="foo"

  local file
  file="${namespace}-annotations-jq.json"
  local json
  json=$(kubectl get ns ${namespace} -o json  2> /dev/null)
  if diff <(echo "${json}" | jq .metadata.annotations) -u ./${file} &> /dev/null; then
    solved
  else
    failed
  fi
}

verify_task5() {
  TASK_NUMBER="5"
  local namespace="foo"

  local file
  file="${namespace}-annotations-jsonpath.json"
  local annotations
  annotations=$(kubectl get ns ${namespace} -o jsonpath="{.metadata.annotations}" 2> /dev/null)
  if diff <(echo -n "${annotations}") -u ./${file} &> /dev/null; then
    solved
  else
    failed
  fi
}

verify_task6() {
  TASK_NUMBER="6"
  local file="all-namespaces.txt"

  if diff <(kubectl get ns -o name) -u ./${file} &> /dev/null; then
    solved
  else
    failed
  fi
}

verify_task7() {
  TASK_NUMBER="7"
  local namespace="blueberry"

  local line_length
  line_length=$(kubectl get -n ${namespace} resourcequotas berry-quota -o jsonpath="{.spec.hard}" | wc -L)
  if [ "${line_length}" != "36" ]; then
    failed
    return
  fi

  local cpu
  cpu=$(kubectl get -n ${namespace} resourcequotas berry-quota -o jsonpath="{.spec.hard.cpu}" 2> /dev/null)
  if [ "${cpu}" != "2" ]; then
    failed
    return
  fi

  local pods
  pods=$(kubectl get -n ${namespace} resourcequotas berry-quota -o jsonpath="{.spec.hard.pods}" 2> /dev/null)
  if [ "${pods}" != "3" ]; then
    failed
    return
  fi

  local memory
  memory=$(kubectl get -n ${namespace} resourcequotas berry-quota -o jsonpath="{.spec.hard.memory}" 2> /dev/null)
  if [ "${memory}" != "2G" ]; then
    failed
    return
  fi

  solved
  return
}

verify_task8() {
  TASK_NUMBER="8"
  local namespace="sunshine"

  local result
  result=$(kubectl apply -f "$(git rev-parse --show-toplevel)/.templates/a_namespaces/task8/limits.yaml" -n ${namespace} 2> /dev/null)
  if  echo "$result" | grep -qi unchanged; then
    solved
  else
    failed
  fi
}

verify_task1
verify_task2
verify_task3
verify_task4
verify_task5
verify_task6
verify_task7
verify_task8
exit 0
