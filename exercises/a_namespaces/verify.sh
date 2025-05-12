#!/bin/bash
RESET_COLOR='\033[0m'
SOLVED_COLOR='\033[0;32m'
FAILED_COLOR='\033[0;31m'

solved() {
    printf "${TASKNAME}: ${SOLVED_COLOR}solved!${RESET_COLOR}\n"
}

failed() {
    printf "${TASKNAME}: ${FAILED_COLOR}failed!${RESET_COLOR}\n"
}

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
    ANNOTATION_HELLO=$(kubectl get ns ${NAMESPACE} -o jsonpath="{.metadata.annotations.hello}")
    ANNOTATION_LEARNING=$(kubectl get ns ${NAMESPACE} -o jsonpath="{.metadata.annotations.learning}")
    if [ ${ANNOTATION_HELLO} == "world" ] && [ ${ANNOTATION_LEARNING} == "kubernetes" ]; then
        solved
    else
        failed
    fi
}

verify_task4() {
    TASKNAME="Task 4"
    NAMESPACE="foo"
    FILE="${NAMESPACE}-annotations-jq.json"
    if diff <(kubectl get ns ${NAMESPACE} -o json | jq .metadata.annotations) -u ./${FILE} &> /dev/null; then
        solved
    else
        failed
    fi
}

verify_task5() {
    TASKNAME="Task 5"
    NAMESPACE="foo"
    FILE="${NAMESPACE}-annotations-jsonpath.json"
    if diff <(kubectl get ns ${NAMESPACE} -o jsonpath="{.metadata.annotations}") -u ./${FILE} &> /dev/null; then
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

verify_task1
verify_task2
verify_task3
verify_task4
verify_task5
verify_task6
exit 0
