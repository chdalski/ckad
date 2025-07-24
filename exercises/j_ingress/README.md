# Ingress

## Task 1

_Objective_:
Create a Deployment and expose it to the outside world using an Ingress resource that routes traffic based on a hostname.

Requirements:

- Create a new Deployment named `web-frontend` in the `default` namespace.
- The Deployment should have 2 replicas.
- The container should be named `web-container` and use the `nginx:1.25` image.
- Create a ClusterIP Service named `frontend-svc` that exposes the Deployment on port 80.
- Create an Ingress resource named `frontend-ingress`.
- The Ingress should route traffic for the host `frontend.example.com` to the `frontend-svc` on port 80.

<details><summary>Help</summary>

1. **Deployment:** You can create a Deployment YAML using `kubectl create deployment web-frontend --image=nginx:1.25 --dry-run=client -o yaml > deployment.yaml`. Then, edit the file to add the replica count.
2. **Service:** Expose the deployment using `kubectl expose deployment web-frontend --port=80 --target-port=80 --name=frontend-svc`.
3. **Ingress:** Create an Ingress manifest. The core part will be the `rules` section.

    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: frontend-ingress
    spec:
      rules:
      - host: "frontend.example.com"
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-svc
                port:
                  number: 80
    ```

</details>

## Task 2

_Objective_:
Configure a single Ingress resource to route requests to two different backend services based on the URL path.

**Predefined Resources:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
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
      - name: api-container
        image: jannylund/simple-api
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: api
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: video-processor
spec:
  replicas: 1
  selector:
    matchLabels:
      app: video
  template:
    metadata:
      labels:
        app: video
    spec:
      containers:
      - name: video-container
        image: stefanprodan/podinfo:6.6.2
        ports:
        - containerPort: 9898
---
apiVersion: v1
kind: Service
metadata:
  name: video-service
spec:
  selector:
    app: video
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9898
```

Requirements:

- Create an Ingress resource named `app-ingress`.
- The Ingress must be configured for the host `app.example.com`.
- Traffic to the path `/api` should be routed to the `api-service` on port 80.
- Traffic to the path `/video` should be routed to the `video-service` on port 80.
- Use the `Prefix` path type for both rules.

<details><summary>Help</summary>

Your Ingress manifest will need a single host rule but multiple paths within that rule's `http` block.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
spec:
  rules:
  - host: "app.example.com"
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
      - path: /video
        pathType: Prefix
        backend:
          service:
            name: video-service
            port:
              number: 80
```

</details>

---

### Task 3: TLS Termination

_Objective_:
Secure an application by configuring TLS on its Ingress resource. A TLS Secret has been pre-created for you.

**Predefined Resources:**

- **Secret Name:** `app-tls-secret`
- **Keys:** `tls.crt` and `tls.key`

Requirements:

- Create a Deployment named `secure-dashboard` using the `traefik/whoami:v1.10` image.
- Create a Service named `dashboard-svc` to expose the deployment on port 80.
- Create an Ingress named `dashboard-ingress`.
- The Ingress must route traffic for the host `dashboard.example.com` to the `dashboard-svc`.
- Configure the Ingress to terminate TLS using the pre-created `app-tls-secret`.

<details>
<summary>Help</summary>

To configure TLS, you need to add a `tls` section to your Ingress spec. This section references the secret that holds the certificate and key.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard-ingress
spec:
  tls:
  - hosts:
    - dashboard.example.com
    secretName: app-tls-secret
  rules:
  - host: "dashboard.example.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dashboard-svc
            port:
              number: 80
```

</details>

---

### Task 4: Ingress Rewrite

_Objective_:
Deploy an application that expects traffic at its root path (`/`). Configure an Ingress to expose this application under a sub-path (`/app`) and rewrite the path before forwarding the request.

Requirements:

- Create a Deployment named `legacy-app` using the `kennethreitz/httpbin` image.
- Create a Service named `legacy-svc` that exposes the deployment's port 80.
- Create an Ingress named `legacy-ingress`.
- The Ingress should route requests from `legacy.example.com/app` to the `legacy-svc`.
- Add the necessary annotation to the Ingress to rewrite the target path to `/`. The path received by the `httpbin` container should be `/` and not `/app`.

<details>
<summary>Help</summary>

The key to this task is the `nginx.ingress.kubernetes.io/rewrite-target` annotation. When the Ingress path is `/app`, you need to rewrite it to `/` for the backend.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: legacy-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - host: "legacy.example.com"
    http:
      paths:
      - path: /app(/|$)(.*)
        pathType: ImplementationSpecific # Or Prefix, depending on the controller version and how it handles regex
        backend:
          service:
            name: legacy-svc
            port:
              number: 80
```

_Note: The exact path and rewrite-target value (`/` or `/$2` or other variants) can depend on the specific Ingress controller version. For the CKAD exam, `/$2` with a regex path is a common pattern to know._

</details>

---

### Task 5: Default Backend

_Objective_:
Configure an Ingress resource with a default backend. This backend will serve all traffic that does not match any of the defined host or path rules, acting as a "catch-all" or custom 404 page.

**Predefined Resources:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: main-site
spec:
  replicas: 1
  selector:
    matchLabels:
      app: main
  template:
    metadata:
      labels:
        app: main
    spec:
      containers:
      - name: main-container
        image: docker/welcome-to-docker
---
apiVersion: v1
kind: Service
metadata:
  name: main-site-svc
spec:
  selector:
    app: main
  ports:
    - port: 80
      targetPort: 80
```

Requirements:

- Create a new Deployment named `error-page-app` using the `gcr.io/google-samples/hello-app:1.0` image.
- Create a ClusterIP Service named `error-page-svc` to expose the `error-page-app` on port 80.
- Create an Ingress named `site-ingress`.
- The Ingress should route traffic for `main.example.com` to the existing `main-site-svc`.
- Configure the Ingress to use `error-page-svc` as the default backend for any requests that do not match the `main.example.com` host rule.

<details>
<summary>Help</summary>

The default backend is defined at the top level of the `spec` section in the Ingress manifest, outside the `rules` array.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: site-ingress
spec:
  defaultBackend:
    service:
      name: error-page-svc
      port:
        number: 80
  rules:
  - host: "main.example.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: main-site-svc
            port:
              number: 80
```

</details>

---

### Task 6: Specify Ingress Class

_Objective_:
In a cluster with multiple Ingress controllers, create an Ingress resource that is explicitly designated to be managed by a specific controller using `ingressClassName`.

**Predefined Resources:**

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: external-nginx
spec:
  controller: [example.com/ingress-controller](https://example.com/ingress-controller)
```

Requirements:

- Create a Deployment named `reports-generator` with the image `mcr.microsoft.com/azuredocs/aci-helloworld`.
- Create a Service named `reports-svc` exposing the deployment on port 80.
- Create an Ingress named `reports-ingress` for the host `reports.example.com`.
- Ensure this Ingress is only handled by the controller associated with the `external-nginx` IngressClass by setting the `ingressClassName` field in the Ingress spec.

<details>
<summary>Help</summary>

This is a straightforward task. You simply need to add the `ingressClassName` field to the `spec` of your Ingress manifest.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: reports-ingress
spec:
  ingressClassName: external-nginx
  rules:
  - host: "reports.example.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: reports-svc
            port:
              number: 80
```

</details>

## Task 1

_Objective_: Expose a simple web application using an Ingress resource.

Requirements:

- Deploy a pod named `web-pod` using the image `nginx:1.25`.
- Create a service named `web-svc` exposing port 80 for the pod.
- Create an Ingress named `web-ingress` that routes HTTP requests for host `web.example.com` to `web-svc`.

<details><summary>help</summary>
</details>

## Task 2

_Objective_: Configure an Ingress to route traffic to different services based on URL paths.

Requirements:

- Deploy two pods: foo-pod (image: hashicorp/http-echo:0.2.3, args: ["-text=foo"]) and bar-pod (image: hashicorp/http-echo:0.2.3, args: ["-text=bar"]).
- Create services foo-svc and bar-svc for each pod, exposing port 5678.
- Create an Ingress named multi-path-ingress:
- Requests to /foo go to foo-svc.
- Requests to /bar go to bar-svc.
- Host: paths.example.com.

<details><summary>help</summary>

- Use the `pathType: Prefix` for each path. - Ensure the correct backend service and port are specified.

</details>

## Task 3

_Objective_: Secure an Ingress with TLS using a pre-created secret.

Requirements:

- Deploy a pod named secure-pod using image nginx:1.25.
- Create a service secure-svc exposing port 80.
- Use the existing secret tls-secret in the same namespace (contains TLS cert and key).
- Create an Ingress named secure-ingress:
- Host: secure.example.com
- Use TLS termination with tls-secret.
- Route all traffic to secure-svc.

**Predefined Resources:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
```

<details><summary>help</summary>

- Reference the secret in the `tls` section of the Ingress. - Set the correct host under both `rules` and `tls`.

</details>

## Task 4

_Objective_: Configure an Ingress with custom NGINX annotations for rewrite and rate limiting.

Requirements:

- Deploy a pod api-pod using image kennethreitz/httpbin.
- Create a service api-svc exposing port 80.
- Create an Ingress api-ingress:
- Host: api.example.com
- Path /v1/(.*) should be rewritten to /$1 before reaching the backend.
- Limit requests to 5 per minute per IP.

<details><summary>help</summary>

- Use NGINX Ingress annotations: `nginx.ingress.kubernetes.io/rewrite-target` and `nginx.ingress.kubernetes.io/limit-rpm`.

</details>

## Task 5

_Objective_: Configure an Ingress to use a default backend for unmatched requests.

Requirements:

- Deploy a pod main-pod (image: nginx:1.25) and a pod default-pod (image: hashicorp/http-echo:0.2.3, args: ["-text=default"]).
- Create services main-svc (port 80) and default-svc (port 5678).
- Create an Ingress default-backend-ingress:
- Host: default.example.com
- Requests to /main go to main-svc.
- All other requests go to default-svc as the default backend.

<details><summary>help</summary>

- Use the `defaultBackend` field in the Ingress spec. - Only one rule for `/main`, rest go to default backend.

</details>

## Task 6

_Objective_: Route traffic to different services based on the host header.

Requirements:

- Deploy two pods: site1-pod (image: nginx:1.25) and site2-pod (image: nginx:1.25).
- Create services site1-svc and site2-svc (port 80).
- Create an Ingress multi-host-ingress:
- Requests to site1.example.com go to site1-svc.
- Requests to site2.example.com go to site2-svc.

<details><summary>help</summary>

- Use two rules in the Ingress, each with a different host.

</details>

## Task 7

_Objective_: Configure an Ingress to use HTTPS when communicating with the backend service.

Requirements:

- Deploy a pod https-backend-pod using image kennethreitz/httpbin.
- Create a service https-backend-svc exposing port 443.
- Create an Ingress https-backend-ingress:
- Host: https-backend.example.com
- Use the annotation to tell NGINX to use HTTPS to the backend.

<details><summary>help</summary>

- Use the annotation: `nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"`.

</details>

## Task 8

_Objective_: Expose an external service via Ingress using an ExternalName service.

Requirements:

- Create an ExternalName service external-svc pointing to example.org.
- Create an Ingress external-ingress:
- Host: external.example.com
- Route all traffic to external-svc on port 80.

<details><summary>help</summary>

- Use `type: ExternalName` in the service. - Ingress backend should reference the service and port.

</details>

## Task 9

_Objective_: Configure custom error pages for 404 and 502 errors using NGINX annotations.

Requirements:

- Deploy a pod error-pod using image nginx:1.25.
- Create a service error-svc exposing port 80.
- Create a pod error-pages-pod using image hashicorp/http-echo:0.2.3, args: ["-text=error"].
- Create a service error-pages-svc exposing port 5678.
- Create an Ingress error-ingress:
- Host: error.example.com
- Route all traffic to error-svc.
- Use NGINX annotations to serve custom error pages from error-pages-svc for 404 and 502 errors.

<details><summary>help</summary>

- Use `nginx.ingress.kubernetes.io/custom-http-errors` and `nginx.ingress.kubernetes.io/default-backend`.

</details>

## Task 10

_Objective_: Restrict access to an Ingress to a specific IP range.

Requirements:

- Deploy a pod restricted-pod using image nginx:1.25.
- Create a service restricted-svc exposing port 80.
- Create an Ingress restricted-ingress:
- Host: restricted.example.com
- Only allow access from 192.168.1.0/24.

<details><summary>help</summary>

- Use the annotation: `nginx.ingress.kubernetes.io/whitelist-source-range`.

</details>

## Task 11

_Objective_: Create an Ingress resource to expose a service externally.

Requirements:

- There is a deployment named `api-backend` in the `net-ingress` namespace.
- The deployment uses the image `hashicorp/http-echo:1.0` with args: `["-text=hello"]`.
- Expose the deployment with a service named `api-svc` on port 5678.
- Create an Ingress named `api-ingress` to expose `/api` path to `api-svc`.

**Predefined Resources:**

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
