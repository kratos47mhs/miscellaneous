
# Kubernetes Resource Dumper

This script exports and cleans Kubernetes resources (e.g., Deployments, Services, PVCs) across one or more namespaces, saving them as neat, readable YAML files.

## 🧾 Features

* Dumps specified Kubernetes resources.
* Supports multiple namespaces.
* Cleans up unnecessary metadata using [`kubectl-neat`](https://github.com/itaysk/kubectl-neat).
* Outputs organized YAML files grouped by resource and namespace.

---

## 📦 Requirements

* [`kubectl`](https://kubernetes.io/docs/tasks/tools/)
* [`kubectl-neat`](https://github.com/itaysk/kubectl-neat)
* [`yq`](https://github.com/mikefarah/yq) (YAML processor)

---

## 🚀 Usage

```bash
./dump-k8s.sh [OPTIONS]
```

### Options

| Option                      | Description                                                                              |
| --------------------------- | ---------------------------------------------------------------------------------------- |
| `-k, --kubeconfig FILE`     | Specify kubeconfig file (default: first file in `$KUBECONFIG` or `~/.kube/`)             |
| `-n, --namespace NAMESPACE` | Comma-separated list of namespaces (default: all namespaces)                             |
| `-r, --resources RESOURCE`  | Comma-separated list of resource types (default: deployments,configmaps,services,pvc,pv) |
| `-h, --help`                | Show help message and exit                                                               |

---

## 📂 Output

The script creates a timestamped folder such as:

```
./k8s-dump-20250509-153012/
└── deployments/
    └── default/
        └── my-deployment.yaml
```

Each file contains a neat YAML of the corresponding resource, stripped of unnecessary metadata.

---

## 🧪 Examples

Dump Deployments and Services from `default` and `kube-system` namespaces:

```bash
./dump-k8s.sh --namespace default,kube-system --resources deployments,services
```

Use a custom kubeconfig file:

```bash
./dump-k8s.sh -k ~/.kube/custom-config.yaml
```

---

## 🛑 Error Handling

* Fails early if `kubectl` or `kubectl-neat` are missing.
* Warns and continues if specific namespace/resource combinations return no results.

---

## ✅ Notes

* The script uses `set -euo pipefail` for safety.
* It selects the first available file in `~/.kube/` if no kubeconfig is provided and `$KUBECONFIG` is unset.
* Uses `yq` to pretty-print cleaned JSON output into YAML.
