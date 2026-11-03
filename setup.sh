#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="com.github.djkawada.nvidia-tune"
USER_HOME="${HOME}"

echo "=========================================================="
echo " Setting up Omarchy NVIDIA GPU Control Plugin            "
echo "=========================================================="

# 1. Make binaries executable
chmod +x "${SCRIPT_DIR}/bin/nvidia-tune-ctl"
chmod +x "${SCRIPT_DIR}/bin/nvidia-tune-ctl.py"

# 2. Privileged system setup
if [ "$EUID" -ne 0 ]; then
    echo "==> Setting up system binaries, sudoers rule, and systemd service (requires sudo)..."
    sudo ln -sfn "${SCRIPT_DIR}/bin/nvidia-tune-ctl" /usr/local/bin/nvidia-tune-ctl
    sudo ln -sfn "${SCRIPT_DIR}/bin/nvidia-tune-ctl.py" /usr/local/bin/nvidia-tune-ctl.py
    sudo install -Dm440 "${SCRIPT_DIR}/99-nvidia-tune.rules" /etc/sudoers.d/99-nvidia-tune
    sudo install -Dm644 "${SCRIPT_DIR}/nvidia-tune.service" /etc/systemd/system/nvidia-tune.service
    sudo systemctl daemon-reload
    sudo systemctl enable --now nvidia-tune.service
else
    ln -sfn "${SCRIPT_DIR}/bin/nvidia-tune-ctl" /usr/local/bin/nvidia-tune-ctl
    ln -sfn "${SCRIPT_DIR}/bin/nvidia-tune-ctl.py" /usr/local/bin/nvidia-tune-ctl.py
    install -Dm440 "${SCRIPT_DIR}/99-nvidia-tune.rules" /etc/sudoers.d/99-nvidia-tune
    install -Dm644 "${SCRIPT_DIR}/nvidia-tune.service" /etc/systemd/system/nvidia-tune.service
    systemctl daemon-reload
    systemctl enable --now nvidia-tune.service
fi

# 3. User plugin directory copy
PLUGINS_DIR="${USER_HOME}/.config/omarchy/plugins"
mkdir -p "${PLUGINS_DIR}"
rm -rf "${PLUGINS_DIR}/${PLUGIN_ID}"
cp -r "${SCRIPT_DIR}" "${PLUGINS_DIR}/${PLUGIN_ID}"
echo "==> Installed plugin to ${PLUGINS_DIR}/${PLUGIN_ID}"

# 4. Register in ~/.config/omarchy/shell.json
SHELL_CONFIG="${USER_HOME}/.config/omarchy/shell.json"
if [ -f "${SHELL_CONFIG}" ]; then
    python3 -c "
import json
with open('${SHELL_CONFIG}', 'r') as f:
    data = json.load(f)

right = data.get('bar', {}).get('layout', {}).get('right', [])
ids = [item.get('id') for item in right if isinstance(item, dict)]

if '${PLUGIN_ID}' not in ids:
    insert_idx = len(right)
    for idx, item in enumerate(right):
        if isinstance(item, dict) and item.get('id') in ['omarchy.network', 'omarchy.audio']:
            insert_idx = idx
            break
    right.insert(insert_idx, {'id': '${PLUGIN_ID}'})
    data['bar']['layout']['right'] = right
    with open('${SHELL_CONFIG}', 'w') as f:
        json.dump(data, f, indent=2)
    print('==> Added ${PLUGIN_ID} to ${SHELL_CONFIG}')
else:
    print('==> ${PLUGIN_ID} is already present in ${SHELL_CONFIG}')
"
fi

# 5. Reload Omarchy shell
if command -v omarchy >/dev/null 2>&1; then
    omarchy refresh shell 2>/dev/null || omarchy restart shell 2>/dev/null || true
    echo "==> Refreshed Omarchy shell."
fi

echo ""
echo "=========================================================="
echo " [SUCCESS] NVIDIA GPU Control plugin is installed!        "
echo " Look at your Omarchy top bar to see the new GPU widget.  "
echo " Left-click opens quick controls, right-click opens the    "
echo " full Profile Editor & Control Center.                    "
echo "=========================================================="
