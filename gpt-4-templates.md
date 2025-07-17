# Templates

## Create a set of tasks

Create an exhaustive set of challenging, real-world Kubernetes CKAD exam tasks for the topic "NetworkPolicies" as a markdown file.

- Use different names per task and always specify which image to use.
- Use the following template for each task.
- Each task should include:
- A unique task number and name.
- An Objective section describing the goal.
- A Requirements section as a bullet list.
- A Predefined Resources: section as YAML manifests (if any).
- A collapsible help section using <details><summary>help</summary></details>.

## Create a verification function for a task

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
- If you need to use index variables (i. e. for "for" loops, etc.) use local variables where possible.
```

```markdown
I'll give you a set of CKAD tasks and I'd like you to create a set of verification scripts for the tasks.

This following definition outlines the mandatory rules and best practices for creating bash verification scripts for CKAD tasks. Please adhere to these specifications ensures consistency, robustness, and clear debugging output.

## 1 Bash Function Structure

- Create a bash function to verify if the task is done successfully.
- Disable shellcheck SC2317 for the function by adding `# shellcheck disable=SC2317` at the beginning of the function body.
- The function name must follow the pattern `verify_task<tasknumber>` (e.g., `verify_task08`).
- At the very beginning of the function, create a non-local variable `TASK_NUMBER="<tasknumber>"` (e.g., `TASK_NUMBER="8"`).

## 2 Variable Handling

- After `TASK_NUMBER`, define local variables for all predefined or expected values (e.g., namespace names, deployment names, replica counts) using the `local` keyword.
- For any other variable that is not predefined, declare it with `local` on the line *just before its first assignment*, rather than declaring all local variables at the beginning.
- Always quote variable expansions (e.g., `"$var"`) to prevent word splitting and globbing issues.
- Do not use temporary files to store values; always use local bash variables.
- Query the Kubernetes API for resource information (e.g., a secret, a deployment) only once. Get the output as JSON and then use that JSON variable for all subsequent parsing with `jq`.
- Use a consistent naming scheme for variables extracted from JSON (e.g., prefix with `dp_` for Deployment-related variables, `svc_` for Service-related variables, `np_` for NetworkPolicy-related variables).
- When using index variables (e.g., for `for` loops), declare them as `local` where possible.

## 3 Error Handling & Control Flow

- Every `jq` and `kubectl` command must be followed by error handling using the `|| { failed; return; }` pattern. This ensures that if a command fails, the verification function immediately calls `failed` and exits.
- Do not use `"$?"` to verify return values. Rely on the `|| { ... }` construct.
- If the verification fails at any point, call the pre-existing bash function `failed` and then immediately `return` from the current function.
- If all checks are successful, call the pre-existing bash function `solved` and then immediately `return` from the current function.

## 4 Debug Messages & Output

- Add a brief comment before each major verification step explaining what is being checked.
- Do not print any information directly to the user's standard output (`stdout`) using `echo` or `print` statements, except for debug messages.
- Make sure not to print any errors to the user's standard error (`stderr`) by redirecting it to `/dev/null` (`2>/dev/null`) where needed for `kubectl` and `jq` commands.
- For all meaningful verification steps and failure points, use the already provided `debug` function to print context-specific debug messages.
  - The `debug` function is defined as follows and must not be redefined in your function:
      ```bash
      debug() {
        [ "${CKAD_EXAM_DEBUG}" = "true" ] && echo "[DEBUG][Task ${TASK_NUMBER}] $1"
      }
      ```
- Debug messages must clearly state what is being checked. In case of failure, they must explicitly state what was expected and what was found.
- If all checks pass, print a debug message indicating successful verification *before* calling `solved`.
- When verifying multiple resources (e.g., iterating through pods), include debug output for each item checked, especially on failure.

## 5 Verification Logic

- Use JSON output from `kubectl` commands and parse it with `jq` for all necessary verifications.
- Verify everything that is specifically expected in the requirements section of the task.

## 6 Formatting

- Use an indent size of 2 spaces.


Can you do that?
```
