#!/bin/bash
set -e
echo "Starting setup for pod environment..."
echo "Configuring Traefik deployment..."

# Patch Traefik deployment to add hostPort for ports 80 and 443
kubectl patch deployment traefik -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/ports/0/hostPort",
    "value": 80
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/ports/1/hostPort",
    "value": 443
  }
]'

echo "Waiting for Traefik rollout to complete..."
kubectl rollout status deployment traefik -n kube-system

echo "Patching Traefik service to ClusterIP type..."
kubectl patch svc traefik -n kube-system -p '{"spec":{"type":"ClusterIP"}}'

echo "Checking Traefik service status..."
kubectl get svc -n kube-system traefik

echo "Traefik configuration completed successfully!"

echo "Setting up lab templates..."
echo "Creating lab template files..."

# Create lab templates directory
echo "Creating lab templates directory..."
cd /root
mkdir lab-templates
cd lab-templates

# Pull necessary images
echo "Pulling necessary images for lab setup..."
sudo ctr -a /run/k3s/containerd/containerd.sock -n k8s.io image pull docker.io/gitpod/openvscode-server:latest
sudo ctr -a /run/k3s/containerd/containerd.sock -n k8s.io image pull tsl0922/ttyd:latest

# Create lab template files
# 📄 1. lab-pod-template.yaml
echo "Creating lab-pod-template.yaml..."

cat > lab-pod-template.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: lab-{labId}
  labels:
    app: lab
    labId: {labId}
spec:
  runtimeClassName: kata-fc
  containers:
  - name: openvscode
    image: gitpod/openvscode-server:latest
    imagePullPolicy: IfNotPresent
    command: ["/bin/sh", "-c"]
    args:
      - |
        /home/.openvscode-server/bin/openvscode-server \
          --host 0.0.0.0 \
          --port 3000 \
          --without-connection-token \
          --accept-server-license-terms &
        sleep infinity
    ports:
    - containerPort: 3000
      name: vscode
    - containerPort: 8080
      name: app
    resources:
      limits:
        cpu: "1"
        memory: "1Gi"
      requests:
        cpu: "0m"
        memory: "0Mi"

  - name: ttyd
    image: tsl0922/ttyd:latest
    imagePullPolicy: IfNotPresent
    command: ["ttyd", "-p", "7681", "--writable", "bash"]
    ports:
    - containerPort: 7681
      name: terminal
    resources:
      limits:
        cpu: "1"
        memory: "1Gi"
      requests:
        cpu: "0m"
        memory: "0Mi"
    tty: true
    stdin: true

  restartPolicy: Never
EOF

# 📄 2. lab-service-template.yaml
echo "Creating lab-service-template.yaml..."
cat > lab-service-template.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: lab-{labId}-svc
  labels:
    app: lab
    labId: {labId}
spec:
  selector:
    app: lab
    labId: {labId}
  ports:
  - name: vscode
    port: 3000
    targetPort: 3000
  - name: terminal
    port: 7681
    targetPort: 7681
  - name: app
    port: 8080
    targetPort: 8080
EOF

# 📄 3. lab-ingress-template.yaml
echo "Creating lab-ingress-template.yaml..."
cat > lab-ingress-template.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: lab-{labId}-ingress
  labels:
    app: lab
    labId: {labId}
spec:
  rules:
  - host: vscode-{labId}.mohit.fixcloud.shop
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: lab-{labId}-svc
            port:
              number: 3000
  - host: terminal-{labId}.mohit.fixcloud.shop
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: lab-{labId}-svc
            port:
              number: 7681
  - host: app-{labId}.mohit.fixcloud.shop
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: lab-{labId}-svc
            port:
              number: 8080
EOF

# 📄 4. lab-networkpolicy-template.yaml
echo "Creating lab-networkpolicy-template.yaml..."
cat > lab-networkpolicy-template.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: lab-{labId}-netpol
  labels:
    app: lab
    labId: {labId}
spec:
  podSelector:
    matchLabels:
      labId: {labId}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Allow all ingress (permissive for now)
  - {}
  egress:
  # Allow all egress (permissive for now)
  - {}
EOF

echo "All lab template files created successfully!"
echo "Created files:"
echo "  - lab-pod-template.yaml"
echo "  - lab-service-template.yaml" 
echo "  - lab-ingress-template.yaml"
echo "  - lab-networkpolicy-template.yaml"

ls -la lab-*-template.yaml
