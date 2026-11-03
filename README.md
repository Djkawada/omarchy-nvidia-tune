# ⚡ NVIDIA GPU Control for Omarchy Linux

An **ultra-lightweight, native GPU telemetry, undervolt, and tuning center** for NVIDIA GeForce RTX graphics cards (Ampere / Ada Lovelace / Turing) on Omarchy Linux (Hyprland / Quickshell).

---

## 🎯 Purpose & Philosophy

Linux gamers and power users on NVIDIA often face a dilemma:
- Proprietary or electron-based GPU overclocking software is either completely unsupported on Wayland, bloated, or non-existent.
- Standard tools like `gwe` (GreenWithEnvy) rely on older X11 `Coolbits`, which do not work on modern Wayland/Hyprland setups.
- Terminal commands like `nvidia-smi` are tedious to run manually, reset on reboot, and lack memory clock offset controls.

**NVIDIA GPU Control** solves this natively:
- **Direct NVML via Python ctypes**: Direct binding to `/usr/lib/libnvidia-ml.so.1` (NVIDIA Management Library). No external runtime dependencies, no bloated daemons.
- **Ampere V/F Curve Clamping (Undervolting)**: Dynamically clamps GPU boost clock to the V/F curve sweetspot (e.g. `1950 MHz @ ~0.900V`), cutting temperatures by 8–15°C and reducing power draw while maintaining maximum sustained clock rates.
- **NVML Memory Offset Tuning**: Leverages modern NVML V/F memory offset APIs to achieve +800 to +1000 MHz VRAM overclocking safely on Linux.
- **100% Native Omarchy & Quickshell**: Smooth 60/144/240Hz rendering directly integrated into your Hyprland top bar, adapting dynamically to the Omarchy desktop color palette.
- **Zero-Password Privilege Escalation**: Includes secure sudoers rules for headless background profile application and a systemd boot service to restore your active profile on boot.

---

## ✨ Features

### 1. 📊 Real-Time Top-Bar Widget
- **Live Indicator**: Visual icon indicating whether the GPU is running in `TUNED` mode or factory `STOCK` default.
- **High-Contrast Telemetry Flyout**:
  - **TEMP**: Live core temperature (°C) and fan speed percentage.
  - **POWER**: Real-time power draw in Watts and current board power limit ceiling.
  - **CORE**: Live graphics clock (MHz) alongside active boost cap.
  - **VRAM**: Live memory clock (MHz) paired with active memory offset (+MHz).
- **One-Click Profile Switcher**: Instantly toggle between tuned, eco, maximum, and stock profiles directly from the bar.
- **Launcher**: Quick access to the full standalone **NVIDIA Control Center** window.

### 2. 🎛️ Standalone NVIDIA Control Center
- **Core Clock Max Slider**: Set exact undervolt/boost clock limits (`1600 MHz` to `2100 MHz`).
- **Memory Clock Offset Slider**: Fine-tune VRAM offsets (`+0 MHz` to `+1200 MHz`).
- **Power Limit Slider**: Configure board power ceiling (`100W` to `240W`+).
- **Custom Profile Management**: Create, edit, rename, and delete custom user profiles stored in `~/.config/nvidia-tune/profiles.json`.
- **Hardware Telemetry HUD**: 5-card live dashboard showing real-time Core Clock, VRAM Clock, Temperature, Power Draw, and VRAM Capacity utilization.

---

## ⚡ Default Included Profiles

| Profile Name | Core Max (Boost Cap) | VRAM Offset | Power Limit | Description |
| :--- | :---: | :---: | :---: | :--- |
| **Tuned (Undervolt & OC)** | **1950 MHz** (~0.900V) | **+800 MHz** | **240W** | *Recommended.* Clamps voltage to ~0.900V for cool temps, eliminates thermal throttling, and boosts VRAM bandwidth by ~11%. |
| **Stock (Factory Default)** | Uncapped (Dynamic) | +0 MHz | 220W | Standard NVIDIA factory out-of-the-box dynamic curve behavior. |
| **Silent & Eco** | **1800 MHz** (~0.825V) | +0 MHz | **180W** | Whisper-quiet fan operation and minimal heat output with ~92% gaming performance. |
| **Maximum Boost OC** | **2050 MHz** | **+1000 MHz** | **240W** | Maximum performance ceiling for high-refresh competitive gaming. |

---

## 📦 Installation & Setup

### Automated Installation

Clone the repository and run the setup script:

```bash
cd ~/Work/omarchy-nvidia-plugin
chmod +x setup.sh
./setup.sh
```

The script will:
1. Make CLI helpers in `bin/` executable.
2. Symlink `nvidia-tune-ctl` to `/usr/local/bin/`.
3. Install passwordless sudoers permissions in `/etc/sudoers.d/99-nvidia-tune`.
4. Install and enable `nvidia-tune.service` to automatically restore active profiles on system boot.
5. Install the plugin into `~/.config/omarchy/plugins/com.github.djkawada.nvidia-tune`.
6. Add the plugin widget to your top bar in `~/.config/omarchy/shell.json`.

---

## 💻 CLI Commands

The backend CLI utility can also be used directly from any terminal or shell script:

```bash
# View live telemetry and current GPU state
nvidia-tune-ctl status

# Apply a profile
nvidia-tune-ctl apply tuned
nvidia-tune-ctl apply stock
nvidia-tune-ctl apply silent

# Toggle between Tuned and Stock
nvidia-tune-ctl toggle

# List all available profiles
nvidia-tune-ctl list

# Apply custom settings directly
nvidia-tune-ctl apply-custom 1950 800 240
```

---

## 🗑️ Uninstallation

To completely remove the plugin, service, and sudoers rules:

```bash
cd ~/Work/omarchy-nvidia-plugin
chmod +x uninstall.sh
./uninstall.sh
```

---

## 📄 License

MIT License. Developed for Omarchy Linux.
