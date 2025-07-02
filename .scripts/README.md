# Scripts

Contains library scripts to be sourced in exercises.

## Verify

I created most of the verification scripts using `OpenAI` (gpt-4).

If you want to create additional exercises this could help:

Provide OpenAi with the task you created and the solution (I simply copied/pasted the block from the markdown file).
Next I asked to create a verification script in the following manner:

```text
Create a bash function to verify if the task is done successfully.
The function name should follow the pattern "verify_task<tasknumber>"
At the beginning of the function create a non-local variable TASK_NUMBER="<tasknumber>".
Make other variables local to the function only and define the variables before assigning any values.
If the verification fails at any point a already existing bash function called "failed" should be called and the function should return.
If all checks are successful a already existing function called "solved" should be called and the function should return.
Also make sure to not output any information to the user, to use json with jq for the verification (if needed), to use and indent size of 2 spaces and to verify everything that is specifically requested (image versions etc.).
```

I still needed to modify the provided functions here and there, but most of the work was done for me 🦥.
