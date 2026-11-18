#!/usr/bin/env bash
set -Eeuo pipefail

VM_NAME="${1:?VM name required}"
CPUS="${2:?CPU count required}"
MEMORY_MB="${3:?Memory in MiB required}"
DISK_SIZE_MB="${4:?Disk size in MiB required}"
HOSTONLY_IP="${5:?Host-only IP required}"
HOSTONLY_ADAPTER="${6:?Host-only adapter required}"
VM_ROOT_INPUT="${7:?VM root directory required}"
IMAGE_PATH="${8:?Rocky image path required}"
IMAGE_SHA256="${9:?Rocky image SHA-256 required}"
SSH_KEY_PATH="${10:?SSH public key path required}"

VM_ROOT="${VM_ROOT_INPUT/#\~/$HOME}"
VM_DIR="${VM_ROOT}/${VM_NAME}"
DISK_PATH="${VM_DIR}/${VM_NAME}.vdi"
SEED_ISO="${VM_DIR}/${VM_NAME}-seed.iso"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: Required command '$1' is missing." >&2
    exit 1
  }
}

for cmd in VBoxManage qemu-img cloud-localds sha256sum; do
  require_command "$cmd"
done

[[ -r "$IMAGE_PATH" ]] || {
  echo "ERROR: Rocky Linux image not found or unreadable: $IMAGE_PATH" >&2
  exit 1
}
[[ "$IMAGE_SHA256" =~ ^[[:xdigit:]]{64}$ ]] || {
  echo "ERROR: Image SHA-256 must be a 64-character hexadecimal digest." >&2
  exit 1
}
[[ -r "$SSH_KEY_PATH" ]] || {
  echo "ERROR: SSH public key not found: $SSH_KEY_PATH" >&2
  exit 1
}

echo "Verifying Rocky Linux image checksum..."
if ! printf '%s  %s\n' "$IMAGE_SHA256" "$IMAGE_PATH" | sha256sum --check --status; then
  echo "ERROR: Rocky Linux image checksum verification failed." >&2
  exit 1
fi

if ! VBoxManage list hostonlyifs | awk -F: -v wanted="$HOSTONLY_ADAPTER" \
  '/^Name:/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); if ($2 == wanted) found = 1 } END { exit !found }'; then
  echo "ERROR: VirtualBox host-only adapter '$HOSTONLY_ADAPTER' was not found." >&2
  exit 1
fi
if VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
  echo "ERROR: VirtualBox VM '$VM_NAME' already exists." >&2
  exit 1
fi

mkdir -p "$VM_DIR"
PUBKEY="$(cat "$SSH_KEY_PATH")"

cat > "${VM_DIR}/user-data" <<EOF
#cloud-config
hostname: ${VM_NAME}
fqdn: ${VM_NAME}.lab.local
manage_etc_hosts: true
ssh_pwauth: false
disable_root: true
users:
  - default
  - name: labadmin
    gecos: Kubernetes Lab Administrator
    groups: [wheel]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - ${PUBKEY}
EOF

cat > "${VM_DIR}/meta-data" <<EOF
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
EOF

cat > "${VM_DIR}/network-config" <<EOF
version: 2
ethernets:
  enp0s3:
    dhcp4: true
    dhcp6: false
  enp0s8:
    dhcp4: false
    dhcp6: false
    addresses:
      - ${HOSTONLY_IP}/24
    optional: true
EOF

cloud-localds --network-config="${VM_DIR}/network-config" \
  "$SEED_ISO" "${VM_DIR}/user-data" "${VM_DIR}/meta-data"
qemu-img convert -p -f qcow2 -O vdi "$IMAGE_PATH" "$DISK_PATH"
VBoxManage modifymedium disk "$DISK_PATH" --resize "$DISK_SIZE_MB"
VBoxManage createvm --name "$VM_NAME" --ostype RedHat_64 --register
VBoxManage modifyvm "$VM_NAME" \
  --cpus "$CPUS" \
  --memory "$MEMORY_MB" \
  --vram 16 \
  --graphicscontroller vmsvga \
  --audio none \
  --usb off \
  --nic1 nat \
  --cableconnected1 on \
  --nic2 hostonly \
  --hostonlyadapter2 "$HOSTONLY_ADAPTER" \
  --cableconnected2 on \
  --boot1 disk \
  --boot2 dvd \
  --boot3 none \
  --boot4 none
VBoxManage storagectl "$VM_NAME" \
  --name "SATA Controller" \
  --add sata \
  --controller IntelAhci \
  --portcount 2 \
  --bootable on
VBoxManage storageattach "$VM_NAME" \
  --storagectl "SATA Controller" \
  --port 0 \
  --device 0 \
  --type hdd \
  --medium "$DISK_PATH"
VBoxManage storageattach "$VM_NAME" \
  --storagectl "SATA Controller" \
  --port 1 \
  --device 0 \
  --type dvddrive \
  --medium "$SEED_ISO"
VBoxManage startvm "$VM_NAME" --type headless

printf 'Created %s (%s); SSH: ssh labadmin@%s\n' "$VM_NAME" "$HOSTONLY_IP" "$HOSTONLY_IP"
