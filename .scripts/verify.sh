#!/bin/bash

RESET_COLOR='\033[0m'
SOLVED_COLOR='\033[0;32m'
FAILED_COLOR='\033[0;31m'

solved() {
  printf "%s: ${SOLVED_COLOR}solved!${RESET_COLOR} 🎉\n" "$TASKNAME"
}

failed() {
  printf "%s: ${FAILED_COLOR}failed!${RESET_COLOR} 😞\n" "$TASKNAME"
}
