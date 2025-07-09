# ReplicaSets

## Task 1

_Objective_: Create a ReplicaSet named "web-rs" to manage 3 replicas of an NGINX web server.

Requirements:

- Create a ReplicaSet named `web-rs` in the default namespace
- The ReplicaSet should maintain 3 replicas
- Use the image `nginx:1.25`
- The pods should be labeled with `app=web`
- Expose port 80 in the pod specification.

<details><summary>help</summary>
</details>

## Task 2

_Objective_: Deploy a ReplicaSet named "api-backend" with a custom label and a specific image version.

Requirements:

- Create a ReplicaSet named `api-backend` in the default namespace
- The ReplicaSet should maintain 2 replicas
- Use the image `myorg/api-server:2.0`
- The pods should be labeled with `tier=backend` and `env=prod`
- Expose port 8080 in the pod specification.

<details><summary>help</summary>
</details>

## Task 3

_Objective_: Create a ReplicaSet named "redis-cache" with a custom selector.

Requirements:

- Create a ReplicaSet named `redis-cache` in the default namespace
- The ReplicaSet should maintain 4 replicas
- Use the image `redis:7.2-alpine`
- The ReplicaSet selector should match pods with the label `role=cache`
- The pods should be labeled with `role=cache` and `component=redis`
- Expose port 6379 in the pod specification.

<details><summary>help</summary>
</details>

## Task 4

_Objective_: Deploy a ReplicaSet named "frontend-rs" with resource limits.

Requirements:

- Create a ReplicaSet named `frontend-rs` in the default namespace
- The ReplicaSet should maintain 2 replicas
- Use the image `myorg/frontend:latest`
- The pods should be labeled with `app=frontend`
- Set CPU limit to `200m` and memory limit to `256Mi` for each pod
- Expose port 3000 in the pod specification.

<details><summary>help</summary>
</details>

## Task 5

_Objective_: Create a ReplicaSet named "logger-rs" with environment variables.

Requirements:

- Create a ReplicaSet named `logger-rs` in the default namespace
- The ReplicaSet should maintain 1 replica
- Use the image `busybox:1.36`
- The pods should be labeled with `app=logger`
- Set an environment variable `LOG_LEVEL=debug` in the pod
- The pod should run the command `["sleep", "3600"]`.

<details><summary>help</summary>
</details>

## Task 6

_Objective_: Deploy a ReplicaSet named "metrics-rs" with a custom namespace.

Requirements:

- Create a namespace named `monitoring`
- Create a ReplicaSet named `metrics-rs` in the `monitoring` namespace
- The ReplicaSet should maintain 2 replicas
- Use the image `prom/prometheus:v2.52.0`
- The pods should be labeled with `app=metrics`
- Expose port 9090 in the pod specification.

<details><summary>help</summary>
</details>

## Task 7

_Objective_: Create a ReplicaSet named "worker-rs" with node affinity.

Requirements:

- Create a ReplicaSet named `worker-rs` in the default namespace
- The ReplicaSet should maintain 3 replicas
- Use the image `alpine:3.20`
- The pods should be labeled with `role=worker`
- Add a node affinity rule to schedule pods only on nodes with the label `disk=ssd`
- The pod should run the command `["sh", "-c", "echo Hello from worker; sleep 3600"]`.

<details><summary>help</summary>
</details>

## Task 8

_Objective_: Deploy a ReplicaSet named "db-rs" with a readiness probe.

Requirements:

- Create a ReplicaSet named `db-rs` in the default namespace
- The ReplicaSet should maintain 2 replicas
- Use the image `postgres:16.3`
- The pods should be labeled with `app=database`
- Add a readiness probe that checks TCP socket on port 5432
- Expose port 5432 in the pod specification.

<details><summary>help</summary>
</details>

## Task 9

_Objective_: Create a ReplicaSet named "job-runner" with a custom restart policy.

Requirements:

- Create a ReplicaSet named `job-runner` in the default namespace
- The ReplicaSet should maintain 2 replicas
- Use the image `python:3.12-slim`
- The pods should be labeled with `app=job`
- The pod should run the command `["python", "-m", "http.server", "8000"]`
- Set the restart policy to `Always`.

<details><summary>help</summary>
</details>

## Task 10

_Objective_: Deploy a ReplicaSet named "static-files" with a volume mount.

Requirements:

- Create a ReplicaSet named `static-files` in the default namespace
- The ReplicaSet should maintain 2 replicas
- Use the image `nginx:1.25`
- The pods should be labeled with `app=static`
- Mount an emptyDir volume at `/usr/share/nginx/html`
- Expose port 80 in the pod specification.

<details><summary>help</summary>
</details>
