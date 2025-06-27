#!/bin/bash

RESET_COLOR='\033[0m'
SOLVED_COLOR='\033[0;32m'
FAILED_COLOR='\033[0;31m'

solved() {
  printf "Task %2s: ${SOLVED_COLOR}solved!${RESET_COLOR} 🎉\n" "$TASK_NUMBER"
}

failed() {
  printf "Task %2s: ${FAILED_COLOR}failed!${RESET_COLOR} 🙈\n" "$TASK_NUMBER"
}
