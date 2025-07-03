# Templates

## Create a set of tasks

```markdown
Create a complete set of kubernetes ckad exam tasks for persistent and ephemeral volumes as markdown file using the following markdown template:

## Task <tasknumber>

_Objective_: <Objective of the task>

Requirements:

- As list...
```

## Create a verification function for a task

```markdown
Create a bash function to verify if the task is done successfully.
The function name should follow the pattern "verify_task<tasknumber>"
At the beginning of the function create a non-local variable TASK_NUMBER="<tasknumber>".
Make other variables local to the function only and define the variables before assigning any values.
If the verification fails at any point a already existing bash function called "failed" should be called and the function should return.
If all checks are successful a already existing function called "solved" should be called and the function should return.
Don't use "$?" to verify return values instead use "|| { failed; return; }".
Also make sure to not output any information to the user, to use json with jq for the verification (if needed), to use and indent size of 2 spaces and to verify everything that is specifically requested in the requirements section of the task (i. e. image versions, capacity, etc.).
```
