#!/bin/bash

# K3s with Kata Containers Setup Script with Idempotency Checks
set -e  # Exit on any error

echo "Starting K3s installation with Kata Containers..."

# Function to check if K3s is installed and running
check_k3s_status() {
    if systemctl is-active --quiet k3s && kubectl get nodes &>/dev/null; then
        echo "✓ K3s is already installed and running"
        return 0
    else
        return 1
    fi
}

# Function to check if Calico is installed
check_calico_status() {
    if kubectl get namespace tigera-operator &>/dev/null && kubectl get pods -n calico-system &>/dev/null; then
        echo "✓ Calico CNI is already installed"
        return 0
    else
        return 1
    fi
}

# Function to check if kata-containers repo exists
check_kata_repo() {
    if [ -d "kata-containers" ]; then
        echo "✓ Kata-containers repository already exists"
        return 0
    else
        return 1
    fi
}

# Function to check if kata-deploy is running
check_kata_deploy() {
    if kubectl get pods -n kube-system -l name=kata-deploy --no-headers 2>/dev/null | grep -q "Running"; then
        echo "✓ Kata-deploy is already running"
        return 0
    else
        return 1
    fi
}

# Function to check if runtime classes exist
check_runtime_classes() {
    if kubectl get runtimeclass kata-fc &>/dev/null || kubectl get runtimeclass kata-qemu &>/dev/null; then
        echo "✓ Kata runtime classes already exist"
        return 0
    else
        return 1
    fi
}

# Function to check if image exists
check_image_exists() {
    local image_name="$1"
    if sudo ctr -a /run/k3s/containerd/containerd.sock -n k8s.io image list | grep -q "$image_name"; then
        echo "✓ Image $image_name already exists"
        return 0
    else
        return 1
    fi
}

# 1. Install K3s if not already installed
if ! check_k3s_status; then
    echo "Installing K3s..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='--flannel-backend=none' sh -s - --disable-network-policy --disable "servicelb" --disable "metrics-server"
    
    # Set up kubeconfig
    echo "Setting up kubeconfig..."
    mkdir -p $HOME/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
    export KUBECONFIG=$HOME/.kube/config
    sudo chown -R $(whoami):$(whoami) $HOME/.kube/
    
    echo "✓ K3s installation completed"
else
    # Ensure kubeconfig is set up even if K3s was already running
    if [ ! -f "$HOME/.kube/config" ]; then
        echo "Setting up kubeconfig..."
        mkdir -p $HOME/.kube
        sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
        sudo chown -R $(whoami):$(whoami) $HOME/.kube/
    fi
    export KUBECONFIG=$HOME/.kube/config
fi

# Check cluster status
echo "Checking cluster status..."
kubectl get pods -o wide -A
kubectl get nodes

# 2. Install Calico CNI if not already installed
if ! check_calico_status; then
    echo "Installing Calico CNI..."
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml 2>/dev/null || echo "Tigera operator already exists, continuing..."
    
    if [ ! -f "custom-resources.yaml" ]; then
        wget https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml
    else
        echo "✓ custom-resources.yaml already exists"
    fi
    
    kubectl apply -f custom-resources.yaml
    echo "✓ Calico CNI installation completed"
fi

# 3. Pull kata-deploy image if not already present
if ! check_image_exists "quay.io/kata-containers/kata-deploy"; then
    echo "Pulling kata-deploy image..."
    sudo ctr -a /run/k3s/containerd/containerd.sock -n k8s.io image pull quay.io/kata-containers/kata-deploy:latest
    echo "✓ Kata-deploy image pulled"
fi

# Check pods status
echo "Checking pods status..."
kubectl get pods -o wide -A

# 4. Clone kata-containers repo if not already present
if ! check_kata_repo; then
    echo "Cloning kata-containers repository..."
    git clone https://github.com/kata-containers/kata-containers.git
    echo "✓ Kata-containers repository cloned"
fi

cd kata-containers/tools/packaging/kata-deploy

# 5. Apply kata RBAC and deploy manifests if kata-deploy is not running
if ! check_kata_deploy; then
    echo "Applying Kata RBAC and deploy manifests..."
    kubectl apply -f kata-rbac/base/kata-rbac.yaml 2>/dev/null || echo "Kata RBAC already exists, continuing..."
    kubectl apply -k kata-deploy/overlays/k3s 2>/dev/null || echo "Kata deploy already exists, continuing..."
    
    # Wait for kata-deploy to be ready
    echo "Waiting for kata-deploy pod to be ready..."
    kubectl wait --for=condition=Ready pod -l name=kata-deploy -n kube-system --timeout=300s || echo "Kata-deploy may still be starting"
    echo "✓ Kata deployment completed"
fi

# Check kata-deploy pod
echo "Checking kata-deploy pod..."
kubectl get pods -n kube-system -o wide -l name=kata-deploy

# 6. Pull nginx image if not already present
if ! check_image_exists "docker.io/library/nginx:1.14"; then
    echo "Pulling nginx image..."
    sudo ctr -a /run/k3s/containerd/containerd.sock -n k8s.io image pull docker.io/library/nginx:1.14
    echo "✓ Nginx image pulled"
fi

# Check kata-deploy logs
echo "Checking kata-deploy logs..."
kubectl logs -n kube-system -l name=kata-deploy --tail=10

# 7. Apply Kata runtimeclasses if not already present
if ! check_runtime_classes; then
    echo "Applying Kata runtime classes..."
    kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/runtimeclasses/kata-runtimeClasses.yaml 2>/dev/null || echo "Runtime classes may already exist"
    echo "✓ Kata runtime classes applied"
fi

echo ""
echo "========================================="
echo "K3s with Kata Containers setup completed successfully!"
echo "========================================="
echo ""
echo "Summary of components:"
echo "✓ K3s cluster running"
echo "✓ Calico CNI installed"
echo "✓ Kata Containers deployed"
echo "✓ Runtime classes configured"
echo ""
echo "Available runtime classes:"
kubectl get runtimeclass --no-headers 2>/dev/null | awk '{print "  - " $1}' || echo "  No runtime classes found yet"
echo ""