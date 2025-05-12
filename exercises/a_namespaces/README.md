# Namespaces

## Task 1

Create a new namespace `ckad`.

<details><summary>help</summary>

```bash
k create namespace ckad
```

</details>

## Task 2

Create a yaml for a new namespace `foo` called `foo.yaml` and apply it to the cluster.

<details><summary>help</summary>

```bash
k create namespace foo --dry-run=client -o yaml > foo.yaml
k apply -f foo.yaml
```

</details>

## Task 3

Add the annotations `learning: kubernetes` and `hello: world` to namespace `foo`.

<details><summary>help</summary>

```bash
k annotate ns foo learning=kubernetes hello=world
```

</details>

## Task 4

List all annotations on namespace `foo` as json using `jq` write the output to a new file `foo-annotations-jq.json`..

<details><summary>help</summary>

```bash
k get ns foo -o json | jq .metadata.annotations > foo-annotations-jq.json
```

</details>

## Task 5

List all annotations on namespace `foo` using jsonpath and write the output to a new file `foo-annotations-jsonpath.json`.

<details><summary>help</summary>

```bash
k get ns foo -o jsonpath="{.metadata.annotations}" > foo-annotations-jsonpath.json
```

</details>

## Task 6

Write the names of all namespaces to a new file called `all-namespaces.txt`.

<details><summary>help</summary>

```bash
k get ns -o name > all-namespaces.txt
```

</details>

## Task 7

TODO: resource quota

## Task 8

TODO: LimitRange
