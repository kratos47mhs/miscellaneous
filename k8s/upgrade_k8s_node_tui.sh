#!/bin/bash

# Dependencies: whiptail, wget, tar, kubectl, kubeadm, systemctl

# Initialize TUI and logging options
VERBOSE=false
log() {
    if $VERBOSE; then echo "$1"; fi
}

# Detect if the node is a master or worker
NODE_NAME=$(hostname)
NODE_ROLE=$(kubectl get nodes $NODE_NAME -o jsonpath='{.metadata.labels.kubernetes\.io/role}' 2>/dev/null)
IS_MASTER=false
if [[ "$NODE_ROLE" == "master" || "$NODE_ROLE" == "control-plane" ]]; then
    IS_MASTER=true
fi

# Prompt for upgrade options
UPGRADE_OPTIONS=$(whiptail --checklist "Select components to upgrade:" 15 60 3 \
    "kubernetes" "Kubernetes" ON \
    "containerd" "Containerd" ON \
    "etcd" "ETCD (Master Only)" ON 3>&1 1>&2 2>&3)

UPGRADE_K8S=false
UPGRADE_CONTAINERD=false
UPGRADE_ETCD=false

if [[ $UPGRADE_OPTIONS == *"kubernetes"* ]]; then UPGRADE_K8S=true; fi
if [[ $UPGRADE_OPTIONS == *"containerd"* ]]; then UPGRADE_CONTAINERD=true; fi
if [[ $UPGRADE_OPTIONS == *"etcd"* && $IS_MASTER ]]; then UPGRADE_ETCD=true; fi

# Prompt for versions using TUI
if $UPGRADE_K8S; then
    NEW_VERSION=$(whiptail --inputbox "Enter Kubernetes version (e.g., v1.28.12):" 8 78 --title "Kubernetes Upgrade" 3>&1 1>&2 2>&3)
fi
if $UPGRADE_CONTAINERD; then
    CONTAINERD_VERSION=$(whiptail --inputbox "Enter containerd version (e.g., 1.7.9):" 8 78 --title "Containerd Upgrade" 3>&1 1>&2 2>&3)
fi
if $UPGRADE_ETCD; then
    ETCD_VERSION=$(whiptail --inputbox "Enter etcd version (e.g., v3.5.11):" 8 78 --title "ETCD Upgrade" 3>&1 1>&2 2>&3)
fi

# Ask user if they want to skip draining
SKIP_DRAIN=false
if whiptail --yesno "Do you want to skip draining the node?" 8 78 --title "Node Draining"; then
    SKIP_DRAIN=true
fi

# Set URLs
if $UPGRADE_K8S; then
    K8S_TAR_URL="https://dl.k8s.io/$NEW_VERSION/kubernetes-node-linux-amd64.tar.gz"
    K8S_TAR_FILE="kubernetes-node-linux-amd64-$NEW_VERSION.tar.gz"
fi
if $UPGRADE_CONTAINERD; then
    CONTAINERD_URL="https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERSION/containerd-$CONTAINERD_VERSION-linux-amd64.tar.gz"
    CONTAINERD_TAR_FILE="containerd-$CONTAINERD_VERSION-linux-amd64.tar.gz"
fi
if $UPGRADE_ETCD; then
    ETCD_URL="https://github.com/etcd-io/etcd/releases/download/$ETCD_VERSION/etcd-$ETCD_VERSION-linux-amd64.tar.gz"
    ETCD_TAR_FILE="etcd-$ETCD_VERSION-linux-amd64.tar.gz"
fi

# Function to validate URL existence
validate_url() {
    log "Validating URL: $1"
    wget --spider -q "$1"
    if [ $? -ne 0 ]; then
        whiptail --msgbox "Error: Version URL does not exist: $1" 8 78 --title "Validation Error"
        exit 1
    fi
}

whiptail --infobox "Validating version URLs..." 8 78
if $UPGRADE_K8S; then validate_url "$K8S_TAR_URL"; fi
if $UPGRADE_CONTAINERD; then validate_url "$CONTAINERD_URL"; fi
if $UPGRADE_ETCD; then validate_url "$ETCD_URL"; fi

# Drain the node if not skipped
if ! $SKIP_DRAIN && $IS_MASTER; then
    whiptail --infobox "Draining node $NODE_NAME..." 8 78
    kubectl drain $NODE_NAME --ignore-daemonsets --delete-local-data --force
fi

# Function to show progress bar
progress_bar() {
    local duration=$1
    local title=$2
    whiptail --gauge "$title" 8 78 0 &
    local pid=$!
    for ((i = 0; i <= 100; i += (100 / duration))); do
        sleep 1
        echo $i | tee /proc/$pid/fd/0
    done
    wait $pid
}

# Upgrade Kubernetes
if $UPGRADE_K8S; then
    progress_bar 5 "Downloading Kubernetes binaries..."
    wget $K8S_TAR_URL -O $K8S_TAR_FILE -c
    progress_bar 5 "Extracting Kubernetes binaries..."
    tar -xzf $K8S_TAR_FILE
    sudo mv kubernetes/node/bin/kubeadm /usr/local/bin/
    sudo mv kubernetes/node/bin/kubelet /usr/local/bin/
    sudo mv kubernetes/node/bin/kubectl /usr/local/bin/
    sudo chmod +x /usr/local/bin/kubeadm /usr/local/bin/kubelet /usr/local/bin/kubectl
fi

# Upgrade containerd
if $UPGRADE_CONTAINERD; then
    progress_bar 5 "Downloading and upgrading containerd..."
    wget $CONTAINERD_URL -O $CONTAINERD_TAR_FILE -c
    progress_bar 5 "Extracting and moving containerd binaries..."
    tar -xzf $CONTAINERD_TAR_FILE
    sudo mv bin/containerd bin/containerd-shim bin/containerd-shim-runc-v2 /usr/bin/
    sudo systemctl restart containerd
fi

# Upgrade etcd (only for master nodes)
if $UPGRADE_ETCD; then
    progress_bar 5 "Downloading and upgrading etcd..."
    wget $ETCD_URL -O $ETCD_TAR_FILE -c
    progress_bar 5 "Extracting and moving etcd binaries..."
    tar -xzf $ETCD_TAR_FILE
    sudo mv etcd-$ETCD_VERSION-linux-amd64/etcd /usr/local/bin/
    sudo mv etcd-$ETCD_VERSION-linux-amd64/etcdctl /usr/local/bin/
    sudo chmod +x /usr/local/bin/etcd /usr/local/bin/etcdctl
    sudo systemctl restart etcd
fi

# Apply Kubernetes upgrade
if $UPGRADE_K8S; then
    progress_bar 5 "Applying Kubernetes upgrade..."
    sudo kubeadm upgrade apply $NEW_VERSION
fi

# Restart kubelet
progress_bar 3 "Restarting kubelet service..."
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Uncordon the node if not skipped
if ! $SKIP_DRAIN && $IS_MASTER; then
    progress_bar 3 "Uncordoning the node $NODE_NAME..."
    kubectl uncordon $NODE_NAME
fi

# Clean up
progress_bar 3 "Cleaning up downloaded files..."
rm -rf kubernetes $K8S_TAR_FILE $CONTAINERD_TAR_FILE
if $UPGRADE_ETCD; then
    rm -rf $ETCD_TAR_FILE etcd-$ETCD_VERSION-linux-amd64
fi

whiptail --msgbox "Upgrade completed successfully." 8 78 --title "Upgrade Complete"

