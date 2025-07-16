# Networking

## Task 1

_Objective_: Create a service with IP whitelisting using NetworkPolicy.

Requirements:

- There is a deployment named `internal-api` in the `internal` namespace.
- The deployment uses the image `nginx:1.25`.
- The container exposes port 80.
- Create a service named `internal-api-svc` of type `ClusterIP` in the `internal` namespace.
- The service should expose port 8080 and target port 80.
- Create a NetworkPolicy named `allow-from-admin` that only allows ingress to the service from pods with the label `role: admin` in the same namespace.

__Predefined Resources:__

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: internal-api
  namespace: internal
spec:
  replicas: 2
  selector:
    matchLabels:
      app: internal-api
  template:
    metadata:
      labels:
        app: internal-api
    spec:
      containers:
      - name: api
        image: nginx:1.25
        ports:
        - containerPort: 80
```

<details><summary>help</summary>
</details>

## Task 2

_Objective_: Create an Ingress resource to expose a service externally.

Requirements:

- There is a deployment named `api-backend` in the `net-ingress` namespace.
- The deployment uses the image `hashicorp/http-echo:1.0` with args: `["-text=hello"]`.
- Expose the deployment with a service named `api-svc` on port 5678.
- Create an Ingress named `api-ingress` to expose `/api` path to `api-svc`.

__Predefined Resources:__

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-backend
  namespace: net-ingress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo:1.0
        args:
        - "-text=hello"
        ports:
        - containerPort: 5678
```

<details><summary>help</summary>
</details>

## Task 3

_Objective_: Restrict pod communication using NetworkPolicy.

Requirements:

- Create a namespace net-policy.
- Deploy two pods: `frontend` (image: `nginx:1.25`) and `backend` (image: `hashicorp/http-echo:1.0`, args: `["-text=backend"]`).
- Create a service `backend-svc` for the backend pod on port 8080.
- Create a NetworkPolicy named `deny-all` that denies all ingress to backend except from frontend.

<details><summary>help</summary>
</details>

## Task 4

_Objective_: Test DNS resolution between pods.

Requirements:

- There is a pod named `api-server` in the `dns-test` namespace.
- Deploy a service named `dns-svc` (ClusterIP) for the `api-server` pod.
- Create a pod `api-test` (image: `busybox:1.36`, command: `sleep 28800`).
- From `api-test`, verify DNS resolution to `dns-svc`.

__Predefined Resources:__

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api-server
  namespace: dns-test
  labels:
    app: api-server
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
```

<details><summary>help</summary>
</details>

## Task 5

_Objective_: Restrict pod access to a backend service to only pods with a specific label.

Requirements:

- Create a namespace called `netpol-demo1`
- Deploy a pod named `backend` using the image `nginx:1.25`
- Deploy a pod named `frontend` using the image `busybox:1.36` with the label `role=frontend`
- Create a NetworkPolicy named `allow-frontend` that only allows pods with label `role=frontend` to connect to the `backend` pod on port 80.

__Predefined Resources:__

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: netpol-demo1
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: netpol-demo1
  labels:
    app: backend
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: netpol-demo1
  labels:
    role: frontend
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
```

<details><summary>help</summary>
</details>

## Task 6

_Objective_: Deny all ingress and egress traffic to a pod except DNS.

Requirements:

- Create a namespace called `netpol-demo2`.
- Deploy a pod named `isolated` using the image `alpine:3.20`.
- Create a NetworkPolicy named `deny-all-except-dns` that denies all ingress and egress except egress to DNS (UDP port 53).

__Predefined Resources:__

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: netpol-demo2
---
apiVersion: v1
kind: Pod
metadata:
  name: isolated
  namespace: netpol-demo2
spec:
  containers:
  - name: alpine
    image: alpine:3.20
    command: ["sleep", "3600"]
```

<details><summary>help</summary>
</details>

## Task 7

_Objective_: Allow traffic to a pod only from a specific namespace.

Requirements:

- Create two namespaces: `netpol-demo3` and `trusted-ns`.
- Deploy a pod named `api-server` in `netpol-demo3` using the image `httpd:2.4`.
- Create a NetworkPolicy named `allow-from-trusted-ns` that only allows ingress traffic to `api-server` from pods in the `trusted-ns` namespace.

__Predefined Resources:__

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: netpol-demo3
---
apiVersion: v1
kind: Namespace
metadata:
  name: trusted-ns
---
apiVersion: v1
kind: Pod
metadata:
  name: api-server
  namespace: netpol-demo3
  labels:
    app: api-server
spec:
  containers:
  - name: httpd
    image: httpd:2.4
```

## Task 8

_Objective_: Allow only HTTP (port 80) traffic to a pod from pods with a specific label in the same namespace.

Requirements:

- Create a namespace called `netpol-demo4`.
- Deploy a pod named `web` using the image `nginx:1.25`.
- Deploy another pod named `client` with label `access=web` using the image `busybox:1.36`.
- Create a NetworkPolicy named `http-only-from-client` that allows only pods with label `access=web` to access `web` on port 80.

__Predefined Resources:__

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: netpol-demo4
---
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: netpol-demo4
  labels:
    app: web
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: netpol-demo4
  labels:
    access: web
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]

```

## Task 9

_Objective_: Allow egress traffic from a pod only to an external IP on a specific port.

Requirements:

- Create a namespace called `netpol-demo5`.
- Deploy a pod named `egress-pod` using the image `alpine:3.20`.
- Create a NetworkPolicy named `allow-egress-external` that allows egress from `egress-pod` only to IP `8.8.8.8` on TCP port 53.

__Predefined Resources:__

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: netpol-demo5
---
apiVersion: v1
kind: Pod
metadata:
  name: egress-pod
  namespace: netpol-demo5
spec:
  containers:
  - name: alpine
    image: alpine:3.20
    command: ["sleep", "3600"]

```

## Task 10

_Objective_: Allow all pods in a namespace to communicate with each other, but deny all ingress from other namespaces.

Requirements:

- Create a namespace called `netpol-demo6`.
- Deploy two pods named `pod-a` and `pod-b` using the image `nginx:1.25`.
- Create a NetworkPolicy named `internal-only` that allows all pods in `netpol-demo6` to communicate with each other, but denies all ingress from other namespaces.

__Predefined Resources:__

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: netpol-demo6
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-a
  namespace: netpol-demo6
  labels:
    app: pod-a
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-b
  namespace: netpol-demo6
  labels:
    app: pod-b
spec:
  containers:
  - name: nginx
    image: nginx:1.25

```

## Task 11

_Objective_: Allow ingress to a pod from a specific IP block only.

Requirements:

- Create a namespace called `netpol-demo7`.
- Deploy a pod named `restricted-pod` using the image `nginx:1.25`.
- Create a NetworkPolicy named `allow-specific-ipblock` that allows ingress to `restricted-pod` only from IP block `10.10.0.0/16`.

__Predefined Resources:__

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: netpol-demo7
---
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
  namespace: netpol-demo7
  labels:
    app: restricted
spec:
  containers:
  - name: nginx
    image: nginx:1.25

```

## Task 12

_Objective_: Allow ingress to a pod on multiple ports from different sources.

Requirements:

- Create a namespace called `netpol-demo8`.
- Deploy a pod named `multi-port-pod` using the image `nginx:1.25`.
- Allow ingress on port 80 from pods with label `role=frontend`.
- Allow ingress on port 443 from pods with label `role=admin`.

__Predefined Resources:__

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: netpol-demo8
---
apiVersion: v1
kind: Pod
metadata:
  name: multi-port-pod
  namespace: netpol-demo8
  labels:
    app: multi-port
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: netpol-demo8
  labels:
    role: frontend
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: admin
  namespace: netpol-demo8
  labels:
    role: admin
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]

```

## Task 13

_Objective_: Allow egress from a pod to another pod in a different namespace.

Requirements:

- Create two namespaces: `netpol-demo9` and `external-ns`.
- Deploy a pod named `source-pod` in `netpol-demo9` using the image `alpine:3.20`.
- Deploy a pod named `target-pod` in `external-ns` using the image `nginx:1.25`.
- Create a NetworkPolicy in `netpol-demo9` that allows egress from `source-pod` to `target-pod` on port 80.

__Predefined Resources:__

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: netpol-demo9
---
apiVersion: v1
kind: Namespace
metadata:
  name: external-ns
---
apiVersion: v1
kind: Pod
metadata:
  name: source-pod
  namespace: netpol-demo9
  labels:
    app: source
spec:
  containers:
  - name: alpine
    image: alpine:3.20
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: target-pod
  namespace: external-ns
  labels:
    app: target
spec:
  containers:
  - name: nginx
    image: nginx:1.25
```

## Task 14

_Objective_: Deny all ingress and egress traffic to a pod.

Requirements:

- Create a namespace called `netpol-demo10`.
- Deploy a pod named `locked-down` using the image `alpine:3.20`.
- Create a NetworkPolicy named `deny-all` that denies all ingress and egress to `locked-down`.

__Predefined Resources:__

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: netpol-demo10
---
apiVersion: v1
kind: Pod
metadata:
  name: locked-down
  namespace: netpol-demo10
spec:
  containers:
  - name: alpine
    image: alpine:3.20
    command: ["sleep", "3600"]
```
