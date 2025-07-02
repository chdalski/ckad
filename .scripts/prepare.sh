#!/bin/bash

CKAD_EXERCISE_DIR=${PWD##*/}
CKAD_WORKSPACE_DIR=$(git rev-parse --show-toplevel)

export CKAD_EXERCISE_DIR
export CKAD_WORKSPACE_DIR

echo "Preparing exercise \"${CKAD_EXERCISE_DIR}\"..."

prepare_kind_cluster() {
  kind create cluster --config "${CKAD_WORKSPACE_DIR}/.cluster/kind-cluster-config.yaml"
  kubectl create ns blueberry > /dev/null
  kubectl create ns sunshine > /dev/null
}

prepare_kind_cluster
