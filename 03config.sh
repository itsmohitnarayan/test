#!/bin/bash
set -e

echo "Configuring containerd for devmapper and kata containers..."

# Backup existing config files
echo "Creating backups of existing configuration files..."
sudo cp /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl.backup 2>/dev/null || echo "No existing config.toml.tmpl found"
sudo cp /opt/kata/containerd/config.d/kata-deploy.toml /opt/kata/containerd/config.d/kata-deploy.toml.backup 2>/dev/null || echo "No existing kata-deploy.toml found"

# 1. Configure main containerd config
echo "Configuring /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl..."
sudo tee /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl > /dev/null << 'EOF'
version = 3
root = "/var/lib/rancher/k3s/agent/containerd"
state = "/run/k3s/containerd"
imports = ["/opt/kata/containerd/config.d/kata-deploy.toml", "/opt/kata/containerd/config.d/kata-deploy.toml"]

[grpc]
address = "/run/k3s/containerd/containerd.sock"

[plugins."io.containerd.internal.v1.opt"]
path = "/var/lib/rancher/k3s/agent/containerd"

[plugins."io.containerd.grpc.v1.cri"]
stream_server_address = "127.0.0.1"
stream_server_port = "10010"

[plugins."io.containerd.cri.v1.runtime"]
enable_selinux = false
enable_unprivileged_ports = true
enable_unprivileged_icmp = true
device_ownership_from_security_context = false

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.runc]
runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.runc.options]
SystemdCgroup = true

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.runhcs-wcow-process]
runtime_type = "io.containerd.runhcs.v1"

[plugins."io.containerd.cri.v1.images"]
snapshotter = "devmapper"
disable_snapshot_annotations = true

[plugins."io.containerd.cri.v1.images".pinned_images]
sandbox = "rancher/mirrored-pause:3.6"

[plugins."io.containerd.cri.v1.images".registry]
config_path = "/var/lib/rancher/k3s/agent/etc/containerd/certs.d"

[plugins."io.containerd.snapshotter.v1.devmapper"]
pool_name = "devpool"
root_path = "/var/lib/containerd/devmapper"
base_image_size = "10GB"
discard_blocks = true
EOF

# 2. Configure kata-deploy.toml with complete configuration
echo "Configuring /opt/kata/containerd/config.d/kata-deploy.toml..."

# Write complete kata-deploy.toml configuration
sudo tee /opt/kata/containerd/config.d/kata-deploy.toml > /dev/null << 'EOF'
[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-clh]
runtime_type = "io.containerd.kata-clh.v2"
runtime_path = "/opt/kata/bin/containerd-shim-kata-v2"
privileged_without_host_devices = true
pod_annotations = ["io.katacontainers.*"]

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-clh.options]
ConfigPath = "/opt/kata/share/defaults/kata-containers/configuration-clh.toml"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-cloud-hypervisor]
runtime_type = "io.containerd.kata-cloud-hypervisor.v2"
runtime_path = "/opt/kata/runtime-rs/bin/containerd-shim-kata-v2"
privileged_without_host_devices = true
pod_annotations = ["io.katacontainers.*"]

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-cloud-hypervisor.options]
ConfigPath = "/opt/kata/share/defaults/kata-containers/runtime-rs/configuration-cloud-hypervisor.toml"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-dragonball]
runtime_type = "io.containerd.kata-dragonball.v2"
runtime_path = "/opt/kata/runtime-rs/bin/containerd-shim-kata-v2"
privileged_without_host_devices = true
pod_annotations = ["io.katacontainers.*"]

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-dragonball.options]
ConfigPath = "/opt/kata/share/defaults/kata-containers/runtime-rs/configuration-dragonball.toml"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-fc]
runtime_type = "io.containerd.kata-fc.v2"
runtime_path = "/opt/kata/bin/containerd-shim-kata-v2"
privileged_without_host_devices = true
pod_annotations = ["io.katacontainers.*"]
snapshotter = "devmapper"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-fc.options]
ConfigPath = "/opt/kata/share/defaults/kata-containers/configuration-fc.toml"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu]
runtime_type = "io.containerd.kata-qemu.v2"
runtime_path = "/opt/kata/bin/containerd-shim-kata-v2"
privileged_without_host_devices = true
pod_annotations = ["io.katacontainers.*"]

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu.options]
ConfigPath = "/opt/kata/share/defaults/kata-containers/configuration-qemu.toml"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-coco-dev]
runtime_type = "io.containerd.kata-qemu-coco-dev.v2"
runtime_path = "/opt/kata/bin/containerd-shim-kata-v2"
privileged_without_host_devices = true
pod_annotations = ["io.katacontainers.*"]

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-coco-dev.options]
ConfigPath = "/opt/kata/share/defaults/kata-containers/configuration-qemu-coco-dev.toml"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-runtime-rs]
runtime_type = "io.containerd.kata-qemu-runtime-rs.v2"
runtime_path = "/opt/kata/runtime-rs/bin/containerd-shim-kata-v2"
privileged_without_host_devices = true
pod_annotations = ["io.katacontainers.*"]

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-runtime-rs.options]
ConfigPath = "/opt/kata/share/defaults/kata-containers/runtime-rs/configuration-qemu-runtime-rs.toml"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-se-runtime-rs]
runtime_type = "io.containerd.kata-qemu-se-runtime-rs.v2"
runtime_path = "/opt/kata/runtime-rs/bin/containerd-shim-kata-v2"
privileged_without_host_devices = true
pod_annotations = ["io.katacontainers.*"]

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-se-runtime-rs.options]
ConfigPath = "/opt/kata/share/defaults/kata-containers/runtime-rs/configuration-qemu-se-runtime-rs.toml"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-snp]
runtime_type = "io.containerd.kata-qemu-snp.v2"
runtime_path = "/opt/kata/bin/containerd-shim-kata-v2"
privileged_without_host_devices = true
pod_annotations = ["io.katacontainers.*"]

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-snp.options]
ConfigPath = "/opt/kata/share/defaults/kata-containers/configuration-qemu-snp.toml"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-tdx]
runtime_type = "io.containerd.kata-qemu-tdx.v2"
runtime_path = "/opt/kata/bin/containerd-shim-kata-v2"
privileged_without_host_devices = true
pod_annotations = ["io.katacontainers.*"]

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-tdx.options]
ConfigPath = "/opt/kata/share/defaults/kata-containers/configuration-qemu-tdx.toml"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-stratovirt]
runtime_type = "io.containerd.kata-stratovirt.v2"
runtime_path = "/opt/kata/bin/containerd-shim-kata-v2"
privileged_without_host_devices = true
pod_annotations = ["io.katacontainers.*"]

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-stratovirt.options]
ConfigPath = "/opt/kata/share/defaults/kata-containers/configuration-stratovirt.toml"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-nvidia-gpu]
runtime_type = "io.containerd.kata-qemu-nvidia-gpu.v2"
runtime_path = "/opt/kata/bin/containerd-shim-kata-v2"
privileged_without_host_devices = true
pod_annotations = ["io.katacontainers.*"]

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-nvidia-gpu.options]
ConfigPath = "/opt/kata/share/defaults/kata-containers/configuration-qemu-nvidia-gpu.toml"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-nvidia-gpu-snp]
runtime_type = "io.containerd.kata-qemu-nvidia-gpu-snp.v2"
runtime_path = "/opt/kata/bin/containerd-shim-kata-v2"
privileged_without_host_devices = true
pod_annotations = ["io.katacontainers.*"]

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-nvidia-gpu-snp.options]
ConfigPath = "/opt/kata/share/defaults/kata-containers/configuration-qemu-nvidia-gpu-snp.toml"

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-nvidia-gpu-tdx]
runtime_type = "io.containerd.kata-qemu-nvidia-gpu-tdx.v2"
runtime_path = "/opt/kata/bin/containerd-shim-kata-v2"
privileged_without_host_devices = true
pod_annotations = ["io.katacontainers.*"]

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata-qemu-nvidia-gpu-tdx.options]
ConfigPath = "/opt/kata/share/defaults/kata-containers/configuration-qemu-nvidia-gpu-tdx.toml"
EOF

# 3. Restart k3s service to apply changes
echo "Restarting k3s service to apply changes..."
sudo systemctl restart k3s
echo "Configuration completed successfully!"
echo ""
echo "Summary of changes:"
echo "1. Updated containerd config with devmapper snapshotter"
echo "2. Configured devmapper pool settings"
echo "3. Added/updated kata-fc runtime with devmapper snapshotter"
echo ""
echo "Next steps:"
echo "1. Restart k3s service: sudo systemctl restart k3s"
echo "2. Verify configuration: kubectl get nodes"
echo "3. Test kata runtime: kubectl get runtimeclass"
echo ""
echo "Backup files created:"
echo "- /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl.backup"
echo "- /opt/kata/containerd/config.d/kata-deploy.toml.backup"