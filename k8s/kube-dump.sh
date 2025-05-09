#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -k, --kubeconfig FILE     Specify kubeconfig file (default: first file in \$KUBECONFIG or ~/.kube/)
  -n, --namespace NAMESPACE Specify namespace(s) (comma-separated, default: all namespaces)
  -r, --resources RESOURCE  Specify resources (comma-separated, default: deployments,configmaps,services,pvc,pv)
  -h, --help                Show this help message and exit

Dependencies:
  - kubectl
  - kubectl-neat (https://github.com/itaysk/kubectl-neat)

Examples:
  $(basename "$0") --namespace default,kube-system --resources deployments,services
  $(basename "$0") -k ~/.kube/custom-config.yaml
EOF
}

# Defaults
NAMESPACES=()
RESOURCES=(deployments configmaps services pvc pv)
KUBECONFIG_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
  -k | --kubeconfig)
    KUBECONFIG_PATH="$2"
    shift 2
    ;;
  -n | --namespace)
    IFS=',' read -r -a NAMESPACES <<<"$2"
    shift 2
    ;;
  -r | --resources)
    IFS=',' read -r -a RESOURCES <<<"$2"
    shift 2
    ;;
  -h | --help)
    show_help
    exit 0
    ;;
  *)
    echo "❌ Unknown option: $1"
    show_help
    exit 1
    ;;
  esac
done

# Determine kubeconfig file
if [[ -z "$KUBECONFIG_PATH" ]]; then
  if [[ -n "${KUBECONFIG:-}" ]]; then
    KUBECONFIG_PATH="${KUBECONFIG%%:*}"
  else
    KUBECONFIG_PATH="$(ls -1 "$HOME/.kube/"* 2>/dev/null | head -n1)"
  fi
fi

if [[ ! -f "$KUBECONFIG_PATH" ]]; then
  echo "❌ kubeconfig file not found: $KUBECONFIG_PATH"
  exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"

# Check kubectl-neat availability
if ! command -v kubectl-neat &>/dev/null && ! kubectl neat --help &>/dev/null; then
  echo "❌ kubectl-neat is not installed or not available in your PATH."
  echo "Install it from: https://github.com/itaysk/kubectl-neat"
  exit 1
fi

OUT_DIR="./k8s-dump-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR"

echo "📁 Output directory: $OUT_DIR"
echo "🔧 Using kubeconfig: $KUBECONFIG_PATH"
[[ ${#NAMESPACES[@]} -eq 0 ]] && echo "🌐 Namespaces: all" || echo "🌐 Namespaces: ${NAMESPACES[*]}"
echo "📦 Resources: ${RESOURCES[*]}"
echo

for res in "${RESOURCES[@]}"; do
  echo "🔵 Dumping $res..."
  mkdir -p "${OUT_DIR}/${res}"

  if [[ ${#NAMESPACES[@]} -eq 0 ]]; then
    mapfile -t items < <(kubectl get "$res" -A -o name)
  else
    items=()
    for ns in "${NAMESPACES[@]}"; do
      mapfile -t ns_items < <(kubectl get "$res" -n "$ns" -o name 2>/dev/null || true)
      items+=("${ns_items[@]}")
    done
  fi

  for item in "${items[@]}"; do
    ns=$(kubectl get "$item" -o jsonpath='{.metadata.namespace}' 2>/dev/null || echo "default")
    name=$(basename "$item")
    mkdir -p "${OUT_DIR}/${res}/${ns}"

    kubectl get "$item" -o json | kubectl neat | yq -P e - >"${OUT_DIR}/${res}/${ns}/${name}.yaml"
  done
done

echo "✅ Dump finished at ${OUT_DIR}/"
