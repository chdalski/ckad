# Kubernetes CKAD Exam - Config Resources Tasks

## Task 1

_Objective_: Create a ConfigMap and mount it as environment variables in a Pod.

Requirements:

- Create a ConfigMap named `app-config` with the following key-value pairs:
  - `APP_MODE`: `production`
  - `APP_VERSION`: `1.0`
- Create a Pod named `app-pod` that uses the `nginx:latest` image.
- Mount the values from the `app-config` ConfigMap as environment variables:
  - `APP_MODE` -> `APP_MODE`
  - `APP_VERSION` -> `APP_VERSION`
- Verify using logs or a shell in the Pod that the environment variables are correctly set.

<details><summary>help</summary>

Create the ConfigMap:

```bash
k create cm app-config --from-literal APP_MODE=production --from-literal APP_VERSION=1.0
```

Create and apply the pod resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - image: nginx:latest
    name: app-pod
    envFrom:
    - configMapRef:
        name: app-config
```

Verify:

```bash
k exec app-pod -it -- env | grep APP_
```

</details>

## Task 2

_Objective_: Create a ConfigMap and use it to mount directories/files into a Pod.

Requirements:

- Create a ConfigMap named `html-config` with the following data:
  - `index.html`: `<h1>Welcome to Kubernetes</h1>`
  - `error.html`: `<h1>Error Page</h1>`
- Create a Pod named `web-pod` that uses the `nginx:latest` image.
- Mount the ConfigMap as a volume at `/usr/share/nginx/html`.
- Check that the files `index.html` and `error.html` are available in the container under the mounted path.

<details><summary>help</summary>

Create the ConfigMap:

```bash
k create cm html-config --from-literal 'index.html=<h1>Welcome to Kubernetes</h1>' --from-literal 'error.html=<h1>Error Page</h1>'
```

Create and apply the pod resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-pod
spec:
  containers:
  - image: nginx:latest
    name: web-pod
    volumeMounts:
    - name: conf-vol
      mountPath: /usr/share/nginx/html
  volumes:
  - name: conf-vol
    configMap:
      name: html-config
```

Verify:

```shell
k exec -it web-pod -- ls /usr/share/nginx/html
```

</details>

## Task 3

_Objective_: Create a Secret and inject it as environment variables in a Pod.

Requirements:

- Create a Secret named `db-credentials` with the following key-value pairs (use base64 encoding as required):
  - `username`: `admin`
  - `password`: `SuperSecretPassword`
- Create a Pod named `db-pod` that uses the `nginx:latest` image.
- Inject the `username` and `password` from the Secret `db-credentials` as environment variables.
- Verify via shell or logs that the environment variables are set correctly.

<details><summary>help</summary>

Create the Secret:

```bash
k create secret generic db-credentials --from-literal username=admin --from-literal password=SuperSecretPassword
```

Create and apply the pod resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: db-pod
spec:
  containers:
  - image: nginx:latest
    name: db-pod
    envFrom:
    - secretRef:
        name: db-credentials
```

Verify:

```bash
k exec -it db-pod -- env | grep username
k exec -it db-pod -- env | grep password
```

</details>

## Task 4

_Objective_: Use a Secret as a volume in a Pod.

Requirements:

- Create a Secret named `tls-secret` with the following key-value pairs (use base64 encoding as required):
  - `tls.crt`: use file `task4.crt`
  - `tls.key`: use file `task4.key`
- Create a Pod named `secure-pod` that uses the `redis:latest` image.
- Mount the Secret `tls-secret` as a volume at `/etc/tls`.
- Verify inside the Pod that the files `tls.crt` and `tls.key` are available at the mounted path.

<details><summary>help</summary>

Create the Secret:

```bash
k create secret tls tls-secret --key ./task4.key --cert ./task4.crt
```

Create and apply the pod resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  containers:
  - image: redis:latest
    name: secure-pod
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/tls
  volumes:
  - name: secret-vol
    secret:
      secretName: tls-secret
```

Verify:

```bash
k exec -it secure-pod -- ls /etc/tls
```

</details>

## Task 5

_Objective_: Use a specific environment variable name for a ConfigMap key.

Requirements:

- Create a ConfigMap named `message-config` with the initial key-value pair:
  - `message`: `Hello, Kubernetes`
- Create a Pod named `message-pod` that uses the `busybox` image with the command: `["sh", "-c", "while true; do echo \"$MESSAGE\"; sleep 5; done"]`.
- Mount the ConfigMap `message-config` as an environment variable `MESSAGE`.
- Verify if the Pod reflects the value in its logs.

<details><summary>help</summary>

Create the ConfigMap:

```bash
k create cm message-config --from-literal message='Hello, Kubernetes'
```

Create and apply the Pod resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: message-pod
spec:
  containers:
  - image: busybox
    name: message-pod
    command: ["sh", "-c", "while true; do echo \"$MESSAGE\"; sleep 5; done"]
    env:
    - name: MESSAGE
      valueFrom:
        configMapKeyRef:
          name: message-config
          key: message
```

Verify:

```bash
k logs message-pod
```

</details>

## Task 6

_Objective_: Create and use multiple ConfigMaps and Secrets.

Requirements:

- Create two ConfigMaps:
  - `frontend-config`:
    - `TITLE`: `Frontend`
  - `backend-config`:
    - `ENDPOINT`: `http://backend.local`
- Create one Secret:
  - `api-secret`:
    - `API_KEY`: `12345`
- Create a Pod named `complex-pod` that uses the `nginx:latest` image.
- Mount the values from:
  - `frontend-config` as environment variables `TITLE`.
  - `backend-config` as environment variables `ENDPOINT`.
  - `api-secret` as an environment variable `API_KEY`.
- Log into the Pod and confirm that all environment variables are set as expected.

<details><summary>help</summary>
</details>

## Task 7

_Objective_: Use ConfigMap and Secret together as volumes.

Requirements:

- Create a ConfigMap named `app-config` with the following data:
  - `config.yml`: "application: setting1"
- Create a Secret named `app-secret` with the following data (use base64 as required):
  - `password`: "mypassword"
- Create a Pod named `volume-pod` that uses the `nginx:alpine` image.
- Mount `app-config` as a volume at `/etc/config`.
- Mount `app-secret` as a volume at `/etc/secret`.
- Verify the contents of the mounted files via shell inside the Pod.

<details><summary>help</summary>
</details>

## Task 8

_Objective_: Create an immutable ConfigMap.

Requirements:

- Create a ConfigMap named `immutable-config` with the following key-value pair:
  - `APP_ENV`: `staging`
- Make the ConfigMap immutable.
- Attempt to edit the ConfigMap after creation and ensure it fails because it is marked as immutable.

<details><summary>help</summary>
</details>
