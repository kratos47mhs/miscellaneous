# 🔍 kube-dump.sh

A robust Bash script to **export and backup Kubernetes resources** across one or multiple namespaces in a clean, human-readable format using `kubectl`, `kubectl-neat`, and `yq`.

---

## 🧰 Features

- Dumps Kubernetes resources to YAML
- Supports multiple namespaces and resource types
- Formats output using [`kubectl-neat`](https://github.com/itaysk/kubectl-neat)
- Saves files to structured directories: `./k8s-dump-YYYYMMDD-HHMMSS/`
- Works with any valid `kubeconfig`

---

## 📦 Requirements

- [`kubectl`](https://kubernetes.io/docs/tasks/tools/)
- [`kubectl-neat`](https://github.com/itaysk/kubectl-neat)
- [`yq`](https://github.com/mikefarah/yq) (v4+)

---

## 🚀 Usage

```bash
./kube-dump.sh [OPTIONS]
````

### Options

| Option               | Description                                                                              |
| -------------------- | ---------------------------------------------------------------------------------------- |
| `-k`, `--kubeconfig` | Path to kubeconfig file (default: uses first in `$KUBECONFIG` or `~/.kube/`)             |
| `-n`, `--namespace`  | Comma-separated list of namespaces (default: all namespaces)                             |
| `-r`, `--resources`  | Comma-separated list of resource types (default: deployments,configmaps,services,pvc,pv) |
| `-h`, `--help`       | Show usage/help message                                                                  |

---

## 📂 Output Structure

```
k8s-dump-20250509-143000/
├── configmaps/
│   └── default/
│       └── my-config.yaml
├── deployments/
│   └── kube-system/
│       └── coredns.yaml
...
```

---

## 🧪 Examples

Dump all default resources from all namespaces:

```bash
./kube-dump.sh
```

Dump specific resources from specific namespaces:

```bash
./kube-dump.sh -n default,kube-system -r deployments,services
```

Use a custom kubeconfig:

```bash
./kube-dump.sh -k ~/.kube/staging-config.yaml
```

---

## 💡 Tips

* Use version control (e.g., git) to track dumped configs over time.
* Use `diff` tools to compare changes between dumps.
* Ideal for backup, troubleshooting, or auditing.

---

## 📜 License

MIT License

---

## 👤 Author

Created by DevOps engineers who needed something more predictable than `kubectl get all` and more readable than raw JSON.

Pull requests welcome! 🙌