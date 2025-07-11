# Templates

## Create a set of tasks

Create an exhaustive set of real kubernetes ckad exam tasks for "deployments" as markdown file using the following markdown template:

```markdown
## Task <tasknumber>

_Objective_: <Objective of the task>

Requirements:

<List of requirements>

__Predefined Resources:__

<As yaml template (if any)>
```

- Use different names per task and always specify which image to use.

## Create a verification function for a task

<!-- ```markdown
Create a bash function to verify if the task is done successfully.
- The function name should follow the pattern "verify_task<tasknumber>"
- At the beginning of the function create a non-local variable TASK_NUMBER="<tasknumber>".
- Next create local variables with predefined values after the TASK_NUMBER.
- For each variable that is not predefined, use local on the line just before its first assignment, instead of declaring all local variables at the beginning of the function
- If the verification fails at any point a already existing bash function called "failed" should be called and the function should return.
- If all checks are successful a already existing function called "solved" should be called and the function should return.
- Don't use "$?" to verify return values instead use "|| { failed; return; }".
- Don't use files to store values - always use local variables
- Make sure not to print any information to the user (stdout)
- Make sure not to print any errors to the user (use "2>/dev/null" where needed)
- Make sure to query the kubernetes api for an information (i. e. a secret resource) only once, get is as json and use the json file afterwards
- Use json with jq for the verification (if needed)
- Use and indent size of 2 spaces
- verify everything that is specifically expected in the requirements section of the task
- Define expected values as local variables at the beginning of the function under the TASK_NUMBER
``` -->

```markdown
Create a bash function to verify if the task is done successfully.
- Disable shellcheck SC2317 for the function (# shellcheck disable=SC2317)
- The function name should follow the pattern "verify_task<tasknumber>"
- At the beginning of the function create a non-local variable TASK_NUMBER="<tasknumber>".
- Next, create local variables with predefined values after the TASK_NUMBER.
- For each variable that is not predefined, use local on the line just before its first assignment, instead of declaring all local variables at the beginning of the function.
- Add a brief comment before each major verification step explaining what is being checked.
- Every jq and kubectl command must be followed by error handling and a debug message if it fails.
- Use a consistent naming scheme for variables extracted from JSON (e.g., prefix with rs_ for ReplicaSet-related variables).
- When verifying multiple resources (e.g., pods), include debug output for each item checked, especially on failure.
- If the verification fails at any point, a pre-existing bash function called "failed" should be called and the function should return.
- If all checks are successful, a pre-existing function called "solved" should be called and the function should return.
- If all checks pass, print a debug message indicating successful verification before calling solved.
- Don't use "$?" to verify return values; instead, use "|| { failed; return; }".
- Don't use files to store values - always use local variables.
- Always quote variable expansions (e.g., "$var") to prevent word splitting and globbing.
- Make sure not to print any information to the user (stdout), except for debug messages as described below.
- Make sure not to print any errors to the user (use "2>/dev/null" where needed).
- Make sure to query the Kubernetes API for information (i.e., a secret resource) only once, get it as JSON, and use the JSON variable afterwards.
- Use JSON with jq for the verification (if needed).
- Use an indent size of 2 spaces.
- Verify everything that is specifically expected in the requirements section of the task.
- Define expected values as local variables at the beginning of the function under the TASK_NUMBER.
- For all meaningful verification steps and failure points, use the already provided debug function to print context-specific debug messages. Do not use echo or print statements directly for debug output.
- The debug function is already defined as follows and should not be redefined in your function:
bash...
debug() {
  [ "${CKAD_EXAM_DEBUG}" = "true" ] && echo "[DEBUG][Task ${TASK_NUMBER}] $1"
}
...
- Debug messages should clearly state what is being checked, and in case of failure, what was expected and what was found.
```
