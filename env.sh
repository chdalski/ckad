#!/bin/sh

# used to list files in the current directory
alias l='ls -lisa'

# used in kubectl create / run commands with $dry (i. e. kubectl create ... $DYAML > resource.yml
DYAML='--dry-run=client -o yaml'
DJSON='--dry-run=client -o json'
export DYAML
export DJSON

# destroy resources instandly (i. e. kubectl delete -f resource.yml $force)
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
