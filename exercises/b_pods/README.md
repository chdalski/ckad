# Pods

## Task 1

Create a pod called `nginx` in namespace `task1` using the `nginx:1.21` image.

_Optionally:_ verify that the pod is running.

<details><summary>help</summary>

```bash
k run nginx --image=nginx:1.21 --restart=Never -n task1
```

</details>

## Task 2

Create a pod called `nginx` in namespace `task2` using the `nginx:1.21` image.
Use port `80` and `expose` the container.
Also add the label `exposed` with value `true`.

<details><summary>help</summary>

```bash
k run nginx --image nginx:1.21 --restart=Never -n task2 --port 80 --expose --labels=exposed=true
```

</details>

## Task 3

Run a container called `busybox` with the command `env`.
Use the `busybox:1.37.0` image and automatically delete the pod after executing.
Save the output to a file called `busybox-env.txt`.

<details><summary>help</summary>

```bash
k run busybox --image busybox:1.37.0 -it --rm --restart Never --command -- env > busybox-env.txt
```

</details>

## Task 4

Create a pod named `envpod` with a container named `ckadenv`, image `nginx` and an environment variable called `CKAD` with value `task4`.

<details><summary>help</summary>

Create the yaml file (i. e. `t4pod.yaml`).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: envpod
spec:
  containers:
  - name: ckadenv
    image: nginx
    env:
    - name: CKAD
      value: task4
```

Apply the yaml file (i. e. `t4pod.yaml`).

```bash
k apply -f t4pod.yaml
```

</details>

## Task 5

Create a pod `task5-app` with a named container `busybox`, image `busybox` and load the environment variables from a config map called `app-config`.
Also make sure the container always restarts and configure it to run the command `["/bin/sh", "-c", "sleep 7200"]`.

<details><summary>help</summary>

Create the yaml file (i. e. `t5pod.yaml`).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: task5-app
spec:
  containers:
  - name: busybox
    image: busybox
    envFrom:
    - configMapRef:
        name: app-config
    command: ["/bin/sh", "-c", "sleep 7200"]
  restartPolicy: Always
```

Apply the yaml file (i. e. `t5pod.yaml`).

```bash
k apply -f t5pod.yaml
```

</details>

## Task 6

Create a pod called `nginx-init` in namespace `task6`.

Define a init container named `busy-init` with image `busybox:1.37.0` and command `["/bin/sh", "-c", "echo 'hello ckad' > /data/index.html]`.
Also mount an `emptyDir` volume called `shared` on path `/data`.

Define a container named `nginx` with image `nginx:1.21` and mount the shared volume on path `/usr/share/nginx/html`.

<details><summary>help</summary>

Create the yaml file (i. e. `t6pod.yaml`).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-init
  namespace: task6
spec:
  initContainers:
  - name: busy-init
    image: busybox:1.37.0
    volumeMounts:
    - name: shared
      mountPath: /data
    command: ["/bin/sh", "-c", "echo 'hello ckad' > /data/index.html"]
  containers:
  - name: nginx
    image: nginx:1.21
    volumeMounts:
    - name: shared
      mountPath: /usr/share/nginx/html
  volumes:
  - name: shared
    emptyDir: {}
```

Apply the yaml file (i. e. `t6pod.yaml`).

```bash
k apply -f t6pod.yaml
```

</details>

## Task 7

Create a multi-container pod called `log-processor` in the `default` namespace, which contains two containers.

An application container called `app`, using the `alpine` image.
It should log the current date to the file `/var/log/app.log` every 10 seconds.

A sidecar container called `log-forwarder`, using a `busybox:1.34` image.
The sidecar container should continuously run the command to tail the log file: `tail -f /var/log/app.log`.

Make sure the directory `/var/log` is persistent between containers using an `emptyDir` volume.

<details><summary>help</summary>

__Note:__
sidecar containers are implemented as init containers with restart policy set to "Always", see the [docs](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/#sidecar-containers-and-pod-lifecycle) for more details.

Create the yaml file (i. e. `t7pod.yaml`).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: log-processor
  namespace: default
spec:
  volumes:
  - name: logs
    emptyDir: {}
  containers:
  - name: app
    image: alpine
    command:
    - /bin/sh
    - -c
    - while true; do echo "$(date)" >> /var/log/app.log; sleep 10; done;
    volumeMounts:
    - name: logs
      mountPath: /var/log
  initContainers:
  - name: log-forwarder
    image: busybox:1.34
    command:
    - /bin/sh
    - -c
    - tail -F /var/log/app.log
    volumeMounts:
    - name: logs
      mountPath: /var/log
    restartPolicy: Always
```

Apply the yaml file (i. e. `t7pod.yaml`).

```bash
k apply -f t7pod.yaml
```

</details>

## TODO

- resource limits
- resource quota
