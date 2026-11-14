#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="com.github.djkawada.nvidia-tune"
USER_HOME="${HOME}"

echo "==> Stopping & removing nvidia-tune.service..."
sudo systemctl disable --now nvidia-tune.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/nvidia-tune.service
sudo systemctl daemon-reload

echo "==> Removing sudoers rule & binary links..."
sudo rm -f /etc/sudoers.d/99-nvidia-tune
sudo rm -f /usr/local/bin/nvidia-tune-ctl
sudo rm -f /usr/local/bin/nvidia-tune-ctl.py

echo "==> Removing plugin directory..."
rm -rf "${USER_HOME}/.config/omarchy/plugins/${PLUGIN_ID}"

echo "==> Removing from ~/.config/omarchy/shell.json..."
SHELL_CONFIG="${USER_HOME}/.config/omarchy/shell.json"
if [ -f "${SHELL_CONFIG}" ]; then
    python3 -c "
import json
with open('${SHELL_CONFIG}', 'r') as f:
    data = json.load(f)

right = data.get('bar', {}).get('layout', {}).get('right', [])
new_right = [item for item in right if isinstance(item, dict) and item.get('id') != '${PLUGIN_ID}']
data['bar']['layout']['right'] = new_right

with open('${SHELL_CONFIG}', 'w') as f:
    json.dump(data, f, indent=2)
"
fi

if command -v omarchy >/dev/null 2>&1; then
    omarchy restart shell 2>/dev/null || true
fi

echo "=========================================================="
echo " [SUCCESS] NVIDIA GPU Control plugin uninstalled cleanly. "
echo "=========================================================="
