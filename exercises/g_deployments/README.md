# Deployments

## Task 1

_Objective_: Create a deployment for a web application.

Requirements:

- Create a deployment named `webapp-deploy`.
- Use the image `nginx:1.25`.
- Set the number of replicas to 3.
- Expose port 80 on the container.

<details><summary>help</summary>

Create the resources with:

```bash
k create deploy webapp-deploy --image nginx:1.25 --replicas 3 --port 80
```

</details>

## Task 2

_Objective_: Update an existing deployment to use a new image version.

Requirements:

- Update the deployment named `api-deploy` to use the image `nginx:1.29`.
- Ensure zero downtime during the update.
- The deployment should have 2 replicas.

<details><summary>help</summary>

Find the deployment:

```bash
k get deploy -A --field-selector metadata.name=api-deploy
```

Edit the deployment:

```bash
k edit -n task2 deploy api-deploy
```

- Update the strategy to `RollingUpdate`.
  - Configure [`maxUnavailable`](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#max-unavailable) to match the criteria.
  - Configure [`maxSurge`](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#max-surge) to match the criteria.
- Update the container image to the expected version.

</details>

## Task 3

_Objective_: Roll back a deployment to a previous version.

Requirements:

- Roll back the deployment named `cache-deploy` to the previous image version.
- The deployment currently uses `redis:8.0.3`, and should be rolled back to `redis:8.0.2`.
- Ensure the deployment has 4 replicas.

<details><summary>help</summary>

Check the rollout history:

```bash
k rollout history deploy cache-deploy
```

Check the details of the previous revision:

```bash
k rollout history deploy cache-deploy --revision 1
```

Rollback to the previous version:

```bash
k rollout undo deploy cache-deploy
```

Verify the desired state:

```bash
k describe deploy cache-deploy | grep -i image:
k describe deploy cache-deploy | grep -i replicas:
```

Scale the deployment:

```bash
k scale deploy cache-deploy --replicas 4
```

Verify all pods are running:

```bash
k get pods -l app=cache-deploy -o wide
```

</details>

## Task 4

_Objective_: Scale a deployment up and down.

Requirements:

- Scale the deployment named `worker-deploy` to 5 replicas.
- After scaling up, scale down to 2 replicas.

<details><summary>help</summary>

Scale up:

```bash
kubectl scale deploy worker-deploy --replicas 5
```

Scale down:

```bash
kubectl scale deploy worker-deploy --replicas 2
```

</details>

## Task 5

_Objective_: Set resource requests and limits for a deployment.

Requirements:

- Create a deployment named `analytics-deploy`.
- Use the image `python:3.12`.
- Use the command `["python", "-c", "import time; time.sleep(99999999)"]`.
- Set CPU request to `100m` and limit to `500m`.
- Set memory request to `128Mi` and limit to `512Mi`.
- Set replicas to 1.

<details><summary>help</summary>

Create the Deployment template:

```bash
k create deploy analytics-deploy --image python:3.12 --replicas 1 --dry-run=client -o yaml > t5deploy.yaml
```

Edit the template and update the container definition (snippet):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  # ...
spec:
  replicas: 1
  # ...
  template:
    # ...
    spec:
      containers:
      - image: python:3.12
        name: python
        command: ["python", "-c", "import time; time.sleep(99999999)"]
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
status: {}
```

</details>

## Task 6

_Objective_: Add environment variables to a deployment.

Requirements:

- Create a deployment named `envtest-deploy` with image `nginx:1.29` and 2 replicas.
- Set environment variable `ENV` to `production`.
- Set environment variable `DEBUG` to `false`.

<details><summary>help</summary>

Create the deployment:

```bash
k create deploy envtest-deploy --image nginx:1.29 --replicas 2
```

Set the env variables:

```bash
k set env deploy envtest-deploy ENV=production DEBUG=false
```

</details>

## Task 7

_Objective_: Use a ConfigMap in a deployment.

Requirements:

- Create a ConfigMap named `app-config` with key `APP_MODE=debug`.
- Create a deployment named `configmap-deploy`.
- Use the image `nginx:1.29.0`.
- Mount the ConfigMap as environment variables in the deployment.
- Set replicas to 1.

<details><summary>help</summary>

Create the ConfigMap:

```bash
k create cm app-config --from-literal APP_MODE=debug
```

Create the Deployment template:

```bash
k create deploy configmap-deploy --image nginx:1.29.0 --replicas 1 --dry-run=client -o yaml > t7deploy.yaml
```

Edit the template and update the container definition (snippet):

```yaml
apiVersion: apps/v1
kind: Deployment
# ...
spec:
  replicas: 1
  # ...
  template:
    # ...
    spec:
      containers:
      - image: nginx:1.29.0
        name: nginx
        envFrom:
        - configMapRef:
            name: app-config
        # ...
```

</details>

## Task 8

_Objective_: Use a Secret in a deployment.

Requirements:

- Create a Secret named `db-secret` with key `DB_PASSWORD=supersecret`.
- Create a deployment named `secret-deploy`.
- Use the image `mysql:8.4`.
- Set the environment variable `MYSQL_ROOT_PASSWORD` from the Secret.
- Set replicas to 1.

<details><summary>help</summary>

Create the Secret:

```bash
k create secret generic db-secret --from-literal DB_PASSWORD=supersecret
```

Create the Deployment template:

```bash
k create deploy secret-deploy --image mysql:8.4 --replicas 1 --dry-run=client -o yaml > t8deploy.yaml
```

Edit the template and update the container definition (snippet):

```yaml
apiVersion: apps/v1
kind: Deployment
# ...
spec:
  replicas: 1
  # ...
  template:
    # ...
    spec:
      containers:
      - image: mysql:8.4
        name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: DB_PASSWORD
        # ...
```

</details>

## Task 9

_Objective_: Add a readiness probe to a deployment.

Requirements:

- Create a deployment named `probe-deploy`.
- Use the image `httpd:2.4`.
- Add a readiness probe that checks path `/` on port 80.
- Set replicas to 2.

<details><summary>help</summary>

Create the Deployment template:

```bash
k create deploy probe-deploy --image httpd:2.4 --replicas 2 --dry-run=client -o yaml > t9deploy.yaml
```

Edit the template and update the container definition (snippet):

```yaml
apiVersion: apps/v1
kind: Deployment
# ...
spec:
  replicas: 2
  # ...
  template:
    # ...
    spec:
      containers:
      - image: httpd:2.4
        name: httpd
        readinessProbe:
          httpGet:
            path: /
            port: 80
        # ...
```

</details>

## Task 10

_Objective_: Add a liveness probe to a deployment.

Requirements:

- Create a deployment named `liveness-deploy`.
- Use the image `redis:7.2`.
- Add a liveness probe that runs the command `redis-cli ping`.
- Perform the probe every 11 seconds.
- Set replicas to 1.

<details><summary>help</summary>

Create the Deployment template:

```bash
k create deploy liveness-deploy --image redis:7.2 --replicas 1 --dry-run=client -o yaml > t10deploy.yaml
```

Edit the template and update the container definition (snippet):

```yaml
apiVersion: apps/v1
kind: Deployment
# ...
spec:
  replicas: 1
  # ...
  template:
    # ...
    spec:
      containers:
      - image: redis:7.2
        name: redis
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          periodSeconds: 11
        # ...
```

</details>

## Task 11

_Objective_: Use a custom label and selector in a deployment.

Requirements:

- Create a deployment named `label-deploy`.
- Use the image `nginx:1.25`.
- Add the label `tier=backend` to the pods.
- Set the deployment selector to match `tier=backend`.
- Set replicas to 3.

<details><summary>help</summary>

Create the Deployment template:

```bash
k create deploy label-deploy --image nginx:1.25 --replicas 3 --dry-run=client -o yaml > t11deploy.yaml
```

Edit the template and update the container definition (snippet):

```yaml
apiVersion: apps/v1
kind: Deployment
# ...
spec:
  replicas: 3
  selector:
    matchLabels:
      app: label-deploy
      tier: backend
  # ...
  template:
    metadata:
      # ...
      labels:
        app: label-deploy
        tier: backend
    spec:
      containers:
      - image: nginx:1.25
        name: nginx
        # ...
```

</details>

## Task 12

_Objective_: Set deployment strategy to Recreate.

Requirements:

- Create a deployment named `recreate-deploy` in namespace `recreate`.
- Use the image `mongo:7.0`.
- Set the deployment strategy to `Recreate`.
- Set replicas to 4.

<details><summary>help</summary>

Create the namespace:

```bash
kubectl create ns recreate
```

Create the Deployment template:

```bash
k create deploy recreate-deploy --image mongo:7.0 --replicas 4 -n recreate --dry-run=client -o yaml > t12deploy.yaml
```

Edit the template and update the container definition (snippet):

```yaml
apiVersion: apps/v1
kind: Deployment
# ...
metadata:
  # ...
  namespace: recreate
spec:
  replicas: 4
  # ...
  strategy:
    type: Recreate
  # ...
```

</details>

## Task 13

_Objective_: Pause a deployment rollout.

Requirements:

- Create a deployment named `pause-deploy`.
- Use the image `httpd:2.4`.
- Pause the rollout of the deployment.
- Set environment variable `TEST` to `true`.

<details><summary>help</summary>

Create the Deployment:

```bash
k create deployment pause-deploy --image httpd:2.4
```

Pause the rollout:

```bash
k rollout pause deployment pause-deploy
```

Set the environment variable:

```bash
k set env deploy pause-deploy TEST=true
```

__NOTE:__ The verification will fail the rollout is resumed.

</details>

## Task 14

_Objective_: Set deployment revision history limit.

Requirements:

- Create a deployment named `history-deploy`.
- Use the image `nginx:1.25`.
- Set the revision history limit to 2.
- Set replicas to 2.

<details><summary>help</summary>

Create the Deployment template:

```bash
k create deploy history-deploy --image nginx:1.25 --replicas 2 --dry-run=client -o yaml > t13deploy.yaml
```

Edit the template and update the container definition (snippet):

```yaml
apiVersion: apps/v1
kind: Deployment
# ...
spec:
  replicas: 2
  revisionHistoryLimit: 2
  # ...
    spec:
      containers:
      - image: nginx:1.25
        name: nginx
        # ...
```

</details>

## Task 15

_Objective_: Add an init container to a deployment.

Requirements:

- Create a deployment named `init-deploy`.
- Use the image `httpd:2.4` for the main container.
- Add an init container using image `busybox:1.36` that runs `echo Init done`.
- Set replicas to 1.

<details><summary>help</summary>

Create the Deployment template:

```bash
k create deploy init-deploy --image httpd:2.4 --replicas 1 --dry-run=client -o yaml > t15deploy.yaml
```

Edit the template and update the container definition (snippet):

```yaml
apiVersion: apps/v1
kind: Deployment
# ...
spec:
  replicas: 1
  # ...
  template:
    # ...
    spec:
      containers:
      - image: httpd:2.4
        name: httpd
        resources: {}
      initContainers:
      - name: busybox
        image: busybox:1.36
        command:
        - /bin/sh
        - -c
        - echo Init done
```

</details>

## Task 16

_Objective_: Use node affinity in a deployment.

Requirements:

- Create a deployment named `affinity-deploy`.
- Use the image `nginx:1.25`.
- Set node affinity to schedule pods only on nodes with label `disktype=ssd`.
- Set replicas to 2.

<details><summary>help</summary>

Create the Deployment template:

```bash
k create deploy affinity-deploy --image nginx:1.25 --replicas 2 --dry-run=client -o yaml > t16deploy.yaml
```

Edit the template and update the container definition (snippet):

```yaml
apiVersion: apps/v1
kind: Deployment
# ...
spec:
  replicas: 2
  # ...
  template:
    # ...
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: disktype
                operator: In
                values:
                - ssd
      containers:
      - image: nginx:1.25
        name: nginx
        # ...
```

</details>

## Task 17

_Objective_: Use a hostPath volume in a deployment.

Requirements:

- Create a deployment named `hostpath-deploy`.
- Use the image `alpine:3.20`.
- Mount the host path `/data/logs` to the container path `/mnt/logs`.
- Set replicas to 1.

<details><summary>help</summary>

</details>

## Task 18

_Objective_: Set deployment minReadySeconds.

Requirements:

- Create a deployment named `minready-deploy`.
- Use the image `nginx:1.25`.
- Set `minReadySeconds` to 10.
- Set replicas to 2.

<details><summary>help</summary>

</details>

## Task 19

_Objective_: Set deployment progressDeadlineSeconds.

Requirements:

- Create a deployment named `deadline-deploy`.
- Use the image `httpd:2.4`.
- Set `progressDeadlineSeconds` to 60.
- Set replicas to 1.

<details><summary>help</summary>

</details>

## Task 20

_Objective_: Use a rolling update strategy with custom parameters.

Requirements:

- Create a deployment named `rollingupdate-deploy`.
- Use the image `nginx:1.25`.
- Set the rolling update strategy with `maxSurge: 2` and `maxUnavailable: 1`.
- Set replicas to 4.

<details><summary>help</summary>

</details>
