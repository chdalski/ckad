# Pods

## Task 1

Create a namespace called `webapp` and create a pod `nginx` with image `nginx` in that namespace.

<details><summary>help</summary>

```bash
k create ns task1
k run nginx --image nginx -n task1
```

</details>

## Task 2

Run a container called `busybox` with the command `printenv`. Use the `busybox` image and automatically delete the pod after executing. Save the output to a file called `busybox-printenv.txt`.

<details><summary>help</summary>

```bash
k run busybox --image busybox -it --rm --restart Never --command -- printenv > busybox-printenv.txt
```

</details>

## Task 3

TODO - add additional labels

## Task 4

TODO:

- resource limits
- resource quota
