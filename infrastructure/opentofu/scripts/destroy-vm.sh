#!/usr/bin/env bash
set -Eeuo pipefail

VM_NAME="${1:?VM name required}"
VM_ROOT_INPUT="${2:?VM root directory required}"
VM_ROOT="${VM_ROOT_INPUT/#\~/$HOME}"
VM_DIR="${VM_ROOT}/${VM_NAME}"

command -v VBoxManage >/dev/null 2>&1 || {
  echo "ERROR: VBoxManage not found." >&2
  exit 1
}

if VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
  VBoxManage controlvm "$VM_NAME" poweroff >/dev/null 2>&1 || true
  VBoxManage unregistervm "$VM_NAME" --delete
fi

rm -rf -- "$VM_DIR"
