# Persistent and Ephemeral Volumes

## Task 1

_Objective_: Create and use a PersistentVolume (PV) and PersistentVolumeClaim (PVC) to mount storage into a pod.

Requirements:

- Define a PersistentVolume (PV) named `data-pv` that provides 1Gi of storage.
- Use accessMode `ReadOnlyMany` to access the volume.
- Ensure the PV uses the `hostPath` storage type at the path `/mnt/data`.
- Create a PersistentVolumeClaim (PVC) named `data-pvc` that requests 500Mi of storage.
- Deploy a pod named `data-pod` with image `nginx`.
- Use the PVC to mount the storage at the path `/data` inside the pod's container.

<details><summary>help</summary>

Create and apply the resources:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-pv
spec:
  storageClassName: standard
  accessModes:
  - ReadOnlyMany
  capacity:
    storage: 1Gi
  hostPath:
    path: /mnt/data
```

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  volumeName: data-pv
  accessModes:
  - ReadOnlyMany
  resources:
    requests:
      storage: 500Mi
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: data-pod
spec:
  containers:
  - image: nginx
    name: data-pod
    volumeMounts:
    - name: data-vol
      mountPath: /data
  volumes:
  - name: data-vol
    persistentVolumeClaim:
      claimName: data-pvc
```

</details>

## Task 2

_Objective_: Configure an ephemeral volume using an emptyDir.

Requirements:

- Create pod named `init-cache` that uses an `emptyDir` volume.
- Mount the `emptyDir` volume with a init container at `/cache`.
- Create a file named `index.html` with content `hello cache` inside the directory.
- Create a container named `app` with the `nginx` image and mount the directory at `/usr/share/nginx/html`.
- Also mount the config map `app-config` to path `/etc/nginx/conf.d`.
- Exec `curl localhost` interactively in the nginx container at least once.

<details><summary>help</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-cache
  namespace: default
spec:
  initContainers:
  - name: init
    image: alpine
    command:
    - sh
    - -c
    - echo "hello cache" > /cache/index.html
    volumeMounts:
    - name: empty-vol
      mountPath: /cache
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: empty-vol
      mountPath: /usr/share/nginx/html
    - name: app-config
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: empty-vol
    emptyDir: {}
  - name: app-config
    configMap:
      name: app-config
```

</details>

## Task 3

_Objective_: Set up a PersistentVolume with access mode restrictions.

Requirements:

- Define a PersistentVolume (PV) with the following properties:
  - Size: 2Gi
  - Storage type: `hostPath` pointing to `/mnt/storage`
  - Access mode: Allow only `ReadWriteOnce`.
- Create a PersistentVolumeClaim (PVC) that matches the PV and requests 1Gi of storage.
- Use the PVC in a pod to ensure that the storage is correctly mounted at `/app`.
- The pod's container should use the `alpine` image and execute `sh` interactively.

<details><summary>help</summary>
</details>

## Task 4

_Objective_: Create and use a ConfigMap-backed ephemeral volume.

Requirements:

- Create a ConfigMap named `app-config` with the following key-value pairs:
  - `config.json`: `{ "setting1": "value1", "setting2": "value2" }`
- Create a pod that uses the ConfigMap as a volume.
- Mount the ConfigMap as a volume at `/etc/config` inside the container.
- The pod's container should use the `nginx` image and serve content.
- Verify that the `config.json` file is present in the `/etc/config` directory inside the container.

<details><summary>help</summary>
</details>

## Task 5

_Objective_: Set up a Secret-backed ephemeral volume.

Requirements:

- Create a Secret named `db-credentials` with the following key-value pairs:
  - `username`: `admin`
  - `password`: `securepassword`
- Create a pod that uses the Secret as a volume and mounts it at `/etc/credentials` inside the container.
- Ensure the container runs the `nginx` image.
- Verify that the Secret contents are available as individual files in `/etc/credentials` inside the container.

<details><summary>help</summary>
</details>

## Task 6

_Objective_: Configure and test multiple volumes in a single pod.

Requirements:

- Create a pod with the following volumes:
  - A `hostPath` volume mounted to `/data` (use `/mnt/data` on the host).
  - An `emptyDir` volume mounted to `/cache`.
- The pod should run the `busybox` container and perform simple data verification in both volumes.
- Verification can include creating files in each mounted directory and ensuring they persist for the `hostPath` but not for the `emptyDir`.

<details><summary>help</summary>
</details>

## Task 7

_Objective_: Define storage quotas for a namespace.

Requirements:

- Create a namespace named `storage-limited`.
- Apply a ResourceQuota to the namespace to restrict:
  - Total number of PersistentVolumeClaims to 3.
  - Total storage requests to 5Gi.
- Attempt to create PVCs in the namespace to test the quota enforcement.

<details><summary>help</summary>
</details>

## Task 8

_Objective_: Use a project volume driver such as `local` for a PersistentVolume.

Requirements:

- Define a PersistentVolume using the `local` storage driver with a path `/mnt/custom`.
- Ensure the PV has a size of 1Gi and allows `ReadWriteOnce` access.
- Set up a PVC that requests storage from the `local` driver-backed PV.
- Create a pod that uses the PVC for storage at `/app-data` and performs basic operations.
- Use the `alpine` image for the pod's container.

<details><summary>help</summary>
</details>

## Task 9

_Objective_: Use subPath mounting within a PersistentVolume.

Requirements:

- Create a PersistentVolume and PersistentVolumeClaim as follows:
  - The PV backs storage using `hostPath` located at `/mnt/volumes`.
  - The PVC requests 2Gi of storage.
- Deploy a pod that mounts the PVC at `/data`.
- Use a `subPath` to mount only the subdirectory `project1` inside `/data`.
- Test that the container can write files in `/data` under the `project1` subdirectory.
- Use the `nginx` image for the container.

<details><summary>help</summary>
</details>

## Task 10

_Objective_: Test dynamic provisioning with a storage class.

Requirements:

- Create a StorageClass named `fast-storage` with the `Retain` reclaim policy and any provisioner you have access to (e.g., `kubernetes.io/no-provisioner` if testing locally).
- Define a PersistentVolumeClaim that dynamically gets bound to a PV using `fast-storage`.
- Deploy a pod that uses the PVC to mount storage at `/mnt` in the container.
- Use the `busybox` image and perform simple read/write operations.

<details><summary>help</summary>
</details>
