# Services

## Task 1

_Objective_: Expose an existing deployment using a ClusterIP service.

Requirements:

- There is a deployment named `web-deploy` in the `default` namespace.
- The deployment uses the image `nginx:1.25`.
- Create a service named `web-svc` of type `ClusterIP`.
- The service should expose port 80 and target port 80 on the pods.

__Predefined Resources:__

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deploy
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
```

<details><summary>help</summary>
</details>

## Task 2

_Objective_: Create a NodePort service for an existing deployment.

Requirements:

- There is a deployment named `api-deploy` in the `dev` namespace.
- The deployment uses the image `httpd:2.4`.
- Create a service named `api-nodeport` of type NodePort.
- The service should expose port 8080 and target port 80 on the pods.
- The NodePort should be set to 30080.

__Predefined Resources:__

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deploy
  namespace: dev
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
      - name: httpd
        image: httpd:2.4
        ports:
        - containerPort: 80
```

<details><summary>help</summary>
</details>

## Task 3

_Objective_: Create a headless service for a StatefulSet.

Requirements:

- There is a StatefulSet named `db-set` in the `database` namespace.
- The StatefulSet uses the image `mongo:6.0`.
- Create a headless service named `db-headless`.
- The service should expose port 27017 and have no cluster IP.

__Predefined Resources:__

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db-set
  namespace: database
spec:
  serviceName: "db-headless"
  replicas: 3
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: mongo
        image: mongo:6.0
        ports:
        - containerPort: 27017
```

<details><summary>help</summary>
</details>

## Task 4

_Objective_: Create an ExternalName service.

Requirements:

- Create a service named `external-svc` in the `default` namespace.
- The service should resolve to the external DNS name `example.com`.
- No selector or ports are required.

<details><summary>help</summary>
</details>

## Task 5

_Objective_: Expose a deployment with a service using custom labels and selectors.

Requirements:

- There is a deployment named `custom-app` in the `prod` namespace.
- The deployment uses the image `busybox:1.36`.
- The pods have the label `tier: backend`.
- Create a service named `custom-svc` of type `ClusterIP`.
- The service should select pods with the label `tier: backend`.
- The service should expose port 9000 and target port 9000.

__Predefined Resources:__

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-app
  namespace: prod
spec:
  replicas: 2
  selector:
    matchLabels:
      tier: backend
  template:
    metadata:
      labels:
        tier: backend
    spec:
      containers:
      - name: busybox
        image: busybox:1.36
        command: ["sleep", "3600"]
        ports:
        - containerPort: 9000
```

<details><summary>help</summary>
</details>

## Task 6

_Objective_: Create a service with multiple ports.

Requirements:

- There is a deployment named `multi-port-app` in the `default` namespace.
- The deployment uses the image `nginx:1.25`.
- The container exposes ports 80 and 443.
- Create a service named `multi-port-svc` of type `ClusterIP`.
- The service should expose ports 80 and 443, targeting the same ports on the pods.

__Predefined Resources:__

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-port-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: multi-port
  template:
    metadata:
      labels:
        app: multi-port
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        - containerPort: 443
```

<details><summary>help</summary>
</details>

## Task 7

_Objective_: Create a service in a custom namespace.

Requirements:

- There is a deployment named `frontend` in the `staging` namespace.
- The deployment uses the image `nginx:1.25`.
- Create a service named `frontend-svc` of type `ClusterIP` in the `staging` namespace.
- The service should expose port 8080 and target port 80.

__Predefined Resources:__

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: staging
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
```

<details><summary>help</summary>
</details>

## Task 8

_Objective_: Update an existing service to change its selector.

Requirements:

- There is a service named `old-svc` in the `default` namespace.
- The service currently selects pods with label `app: old`.
- Change the selector to `app: new`.
- No changes to ports or type are required.

__Predefined Resources:__

```yaml
apiVersion: v1
kind: Service
metadata:
  name: old-svc
spec:
  selector:
    app: old
  ports:
  - port: 80
    targetPort: 80
```

<details><summary>help</summary>
</details>

## Task 9

_Objective_: Create a service for a deployment with a custom target port.

Requirements:

- There is a deployment named `custom-port-app` in the `default` namespace.
- The deployment uses the image `nginx:1.25`.
- The container exposes port 8081.
- Create a service named `custom-port-svc` of type `ClusterIP`.
- The service should expose port 80 and target port 8081.

__Predefined Resources:__

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-port-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: custom-port
  template:
    metadata:
      labels:
        app: custom-port
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 8081
```

<details><summary>help</summary>
</details>

## Task 10

_Objective_: Create a service with session affinity.

Requirements:

- There is a deployment named `session-app` in the `default` namespace.
- The deployment uses the image `nginx:1.25`.
- Create a service named `session-svc` of type `ClusterIP`.
- The service should expose port 80 and target port 80.
- Enable session affinity based on client IP.

__Predefined Resources:__

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: session-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: session
  template:
    metadata:
      labels:
        app: session
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
```

<details><summary>help</summary>
</details>
