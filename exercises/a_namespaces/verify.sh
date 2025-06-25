#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

verify_task1() {
  TASKNAME="Task 1"
  NAMESPACE="ckad"
  if kubectl get ns "$NAMESPACE" &> /dev/null; then
    solved
  else
    failed
  fi
}

verify_task2() {
  TASKNAME="Task 2"
  NAMESPACE="foo"
  if [ ! -f ./"$NAMESPACE".yaml ]; then
    failed
  else
    if kubectl get ns "$NAMESPACE" &> /dev/null; then
      solved
    else
      failed
    fi
  fi
}

verify_task3() {
  TASKNAME="Task 3"
  NAMESPACE="foo"
  ANNOTATION_HELLO=$(kubectl get ns ${NAMESPACE} -o jsonpath="{.metadata.annotations.hello}" 2> /dev/null)
  ANNOTATION_LEARNING=$(kubectl get ns ${NAMESPACE} -o jsonpath="{.metadata.annotations.learning}" 2> /dev/null)
  if [ "${ANNOTATION_HELLO}" == "world" ] && [ "${ANNOTATION_LEARNING}" == "kubernetes" ]; then
    solved
  else
    failed
  fi
}

verify_task4() {
  TASKNAME="Task 4"
  NAMESPACE="foo"
  FILE="${NAMESPACE}-annotations-jq.json"
  JSON=$(kubectl get ns ${NAMESPACE} -o json  2> /dev/null)
  if diff <(echo "${JSON}" | jq .metadata.annotations) -u ./${FILE} &> /dev/null; then
    solved
  else
    failed
  fi
}

verify_task5() {
  TASKNAME="Task 5"
  NAMESPACE="foo"
  FILE="${NAMESPACE}-annotations-jsonpath.json"
  ANNOTATIONS=$(kubectl get ns ${NAMESPACE} -o jsonpath="{.metadata.annotations}" 2> /dev/null)
  if diff <(echo -n "${ANNOTATIONS}") -u ./${FILE} &> /dev/null; then
    solved
  else
    failed
  fi
}

verify_task6() {
  TASKNAME="Task 6"
  FILE="all-namespaces.txt"
  if diff <(kubectl get ns -o name) -u ./${FILE} &> /dev/null; then
    solved
  else
    failed
  fi
}

verify_task7() {
  TASKNAME="Task 7"
  NAMESPACE="blueberry"
  LINE_LENGTH=$(kubectl get -n ${NAMESPACE} resourcequotas berry-quota -o jsonpath="{.spec.hard}" | wc -L)
  CPU=$(kubectl get -n ${NAMESPACE} resourcequotas berry-quota -o jsonpath="{.spec.hard.cpu}" 2> /dev/null)
  PODS=$(kubectl get -n ${NAMESPACE} resourcequotas berry-quota -o jsonpath="{.spec.hard.pods}" 2> /dev/null)
  MEMORY=$(kubectl get -n ${NAMESPACE} resourcequotas berry-quota -o jsonpath="{.spec.hard.memory}" 2> /dev/null)
  if [ "${LINE_LENGTH}" == "36" ] && [ "${CPU}" == "2" ] && [ "${PODS}" == "3" ] && [ "${MEMORY}" == "2G" ]; then
    solved
  else
    failed
  fi
}

verify_task8() {
  TASKNAME="Task 8"
  NAMESPACE="sunshine"
  TEMPLATE_DIR="$(git rev-parse --show-toplevel)/.templates/a_namespaces/task_8"
  ACTUAL=$(kubectl apply -f "${TEMPLATE_DIR}/limits.yaml" -n ${NAMESPACE} 2> /dev/null)
  if  echo "$ACTUAL" | grep -qi unchanged; then
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
