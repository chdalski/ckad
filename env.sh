#!/bin/sh

# used to list files in the current directory
alias l='ls -lisa'

# used in kubectl create / run commands with $dry (i. e. kubectl create ... $DRYY > resource.yml
DRYY='--dry-run=client -o yaml'
DRYJ='--dry-run=client -o json'
export DRYY
export DRYJ

# destroy resources instandly (i. e. kubectl delete -f resource.yml $FORCE)
FORCE='--grace-period 0 --force'
export FORCE

# set default namespace
sdn() { kubectl config set-context --current --namespace="$1" ; }

# reset default namespace
rdn() { kubectl config set-context --current --namespace=default ; }

# organize files per question
mkcd() { mkdir -p "$@" && cd "$@" ; }

# create/destroy from yaml faster
alias kaf='k apply -f'
alias kdf='k delete -f'
