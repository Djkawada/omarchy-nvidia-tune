#!/usr/bin/env python3
"""
NVIDIA RTX Tuning Backend (NVML-powered) for Omarchy Linux
Provides hardware control, live metrics, profile management, and system persistence.
"""

from __future__ import annotations

import argparse
import ctypes
import json
import os
import sys
from pathlib import Path

# --- NVML Structures & Constants ---
NVML_CLOCK_GRAPHICS = 0
NVML_CLOCK_SM = 1
NVML_CLOCK_MEM = 2
NVML_CLOCK_VIDEO = 3

NVML_TEMPERATURE_GPU = 0
NVML_SUCCESS = 0


class NvmlMemory(ctypes.Structure):
    _fields_ = [
        ("total", ctypes.c_ulonglong),
        ("free", ctypes.c_ulonglong),
        ("used", ctypes.c_ulonglong),
    ]


class NvmlUtilization(ctypes.Structure):
    _fields_ = [
        ("gpu", ctypes.c_uint),
        ("memory", ctypes.c_uint),
    ]


class NVMLClient:
    def __init__(self):
        try:
            self.nvml = ctypes.CDLL("libnvidia-ml.so.1")
        except OSError as e:
            raise RuntimeError(f"Failed to load libnvidia-ml.so.1: {e}")

        ret = self.nvml.nvmlInit_v2()
        if ret != NVML_SUCCESS:
            raise RuntimeError(f"nvmlInit_v2 failed with error code {ret}")

        self.handle = ctypes.c_void_p()
        ret = self.nvml.nvmlDeviceGetHandleByIndex_v2(0, ctypes.byref(self.handle))
        if ret != NVML_SUCCESS:
            raise RuntimeError(f"Failed to get handle for GPU 0: error {ret}")

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        try:
            self.nvml.nvmlShutdown()
        except Exception:
            pass

    def get_name(self) -> str:
        buf = ctypes.create_string_buffer(96)
        if self.nvml.nvmlDeviceGetName(self.handle, buf, 96) == NVML_SUCCESS:
            return buf.value.decode("utf-8")
        return "NVIDIA GPU"

    def get_driver_version(self) -> str:
        buf = ctypes.create_string_buffer(80)
        if self.nvml.nvmlSystemGetDriverVersion(buf, 80) == NVML_SUCCESS:
            return buf.value.decode("utf-8")
        return "Unknown"

    def get_temperature(self) -> int:
        temp = ctypes.c_uint()
        if self.nvml.nvmlDeviceGetTemperature(self.handle, NVML_TEMPERATURE_GPU, ctypes.byref(temp)) == NVML_SUCCESS:
            return int(temp.value)
        return 0

    def get_power_usage_w(self) -> float:
        power = ctypes.c_uint()
        if self.nvml.nvmlDeviceGetPowerUsage(self.handle, ctypes.byref(power)) == NVML_SUCCESS:
            return round(power.value / 1000.0, 1)
        return 0.0

    def get_power_limit_w(self) -> int:
        pl = ctypes.c_uint()
        if self.nvml.nvmlDeviceGetEnforcedPowerLimit(self.handle, ctypes.byref(pl)) == NVML_SUCCESS:
            return int(pl.value // 1000)
        return 220

    def get_power_constraints_w(self) -> tuple[int, int]:
        min_p = ctypes.c_uint()
        max_p = ctypes.c_uint()
        if self.nvml.nvmlDeviceGetPowerManagementLimitConstraints(self.handle, ctypes.byref(min_p), ctypes.byref(max_p)) == NVML_SUCCESS:
            return int(min_p.value // 1000), int(max_p.value // 1000)
        return 100, 240

    def get_core_clock_mhz(self) -> int:
        clock = ctypes.c_uint()
        if self.nvml.nvmlDeviceGetClockInfo(self.handle, NVML_CLOCK_GRAPHICS, ctypes.byref(clock)) == NVML_SUCCESS:
            return int(clock.value)
        return 0

    def get_memory_clock_mhz(self) -> int:
        clock = ctypes.c_uint()
        if self.nvml.nvmlDeviceGetClockInfo(self.handle, NVML_CLOCK_MEM, ctypes.byref(clock)) == NVML_SUCCESS:
            return int(clock.value)
        return 0

    def get_mem_offset_mhz(self) -> int:
        if hasattr(self.nvml, "nvmlDeviceGetMemClkVfOffset"):
            offset = ctypes.c_int()
            if self.nvml.nvmlDeviceGetMemClkVfOffset(self.handle, ctypes.byref(offset)) == NVML_SUCCESS:
                return int(offset.value)
        return 0

    def get_fan_speed_pct(self) -> int:
        fan = ctypes.c_uint()
        if self.nvml.nvmlDeviceGetFanSpeed(self.handle, ctypes.byref(fan)) == NVML_SUCCESS:
            return int(fan.value)
        return 0

    def get_utilization(self) -> tuple[int, int]:
        util = NvmlUtilization()
        if self.nvml.nvmlDeviceGetUtilizationRates(self.handle, ctypes.byref(util)) == NVML_SUCCESS:
            return int(util.gpu), int(util.memory)
        return 0, 0

    def get_vram(self) -> tuple[int, int, int]:
        mem = NvmlMemory()
        if self.nvml.nvmlDeviceGetMemoryInfo(self.handle, ctypes.byref(mem)) == NVML_SUCCESS:
            used_mb = int(mem.used // (1024 * 1024))
            total_mb = int(mem.total // (1024 * 1024))
            free_mb = int(mem.free // (1024 * 1024))
            return used_mb, total_mb, free_mb
        return 0, 8192, 0

    def set_power_limit_w(self, watts: int) -> bool:
        watts = max(100, min(240, watts))
        milliwatts = ctypes.c_uint(watts * 1000)
        ret = self.nvml.nvmlDeviceSetPowerManagementLimit(self.handle, milliwatts)
        return ret == NVML_SUCCESS

    def set_gpu_locked_clocks(self, min_mhz: int, max_mhz: int) -> bool:
        if max_mhz <= 0:
            ret = self.nvml.nvmlDeviceResetGpuLockedClocks(self.handle)
            return ret == NVML_SUCCESS
        min_c = ctypes.c_uint(min_mhz)
        max_c = ctypes.c_uint(max_mhz)
        ret = self.nvml.nvmlDeviceSetGpuLockedClocks(self.handle, min_c, max_c)
        return ret == NVML_SUCCESS

    def reset_gpu_locked_clocks(self) -> bool:
        ret = self.nvml.nvmlDeviceResetGpuLockedClocks(self.handle)
        return ret == NVML_SUCCESS

    def set_mem_offset_mhz(self, offset_mhz: int) -> bool:
        if hasattr(self.nvml, "nvmlDeviceSetMemClkVfOffset"):
            val = ctypes.c_int(offset_mhz)
            ret = self.nvml.nvmlDeviceSetMemClkVfOffset(self.handle, val)
            return ret == NVML_SUCCESS
        return False


# --- Configuration & Profile Manager ---
DEFAULT_PROFILES = {
    "tuned": {
        "id": "tuned",
        "name": "Tuned (Undervolt & OC)",
        "description": "1950 MHz @ ~0.900V, +800 MHz VRAM, 240W Limit (Max sustained FPS & cool temps)",
        "core_min": 210,
        "core_max": 1950,
        "mem_offset": 800,
        "power_limit": 240,
        "is_system": True,
    },
    "stock": {
        "id": "stock",
        "name": "Stock (Factory Default)",
        "description": "NVIDIA default factory behavior (dynamic boost, +0 MHz VRAM, 220W Limit)",
        "core_min": 210,
        "core_max": 0,  # 0 indicates reset / uncapped
        "mem_offset": 0,
        "power_limit": 220,
        "is_system": True,
    },
    "silent": {
        "id": "silent",
        "name": "Silent & Eco",
        "description": "1800 MHz @ ~0.825V, +0 MHz VRAM, 180W Limit (Minimal heat and whisper quiet fans)",
        "core_min": 210,
        "core_max": 1800,
        "mem_offset": 0,
        "power_limit": 180,
        "is_system": True,
    },
    "maximum": {
        "id": "maximum",
        "name": "Maximum Boost OC",
        "description": "2050 MHz boost limit, +1000 MHz VRAM, 240W Limit",
        "core_min": 210,
        "core_max": 2050,
        "mem_offset": 1000,
        "power_limit": 240,
        "is_system": True,
    },
}


def get_config_dir() -> Path:
    # Prefer user config directory
    home = os.environ.get("HOME", "")
    if home and home != "/root":
        p = Path(home) / ".config" / "nvidia-tune"
    else:
        # Check if SUDO_USER is set
        sudo_user = os.environ.get("SUDO_USER")
        if sudo_user and sudo_user != "root":
            p = Path(f"/home/{sudo_user}/.config/nvidia-tune")
        else:
            p = Path("/etc/nvidia-tune")
    p.mkdir(parents=True, exist_ok=True)
    return p


def get_profiles_file() -> Path:
    return get_config_dir() / "profiles.json"


def get_state_file() -> Path:
    return get_config_dir() / "active.json"


def get_system_state_file() -> Path:
    return Path("/etc/nvidia-tune/active.json")


def load_profiles() -> dict[str, dict]:
    f = get_profiles_file()
    profiles = dict(DEFAULT_PROFILES)
    if f.exists():
        try:
            with f.open("r", encoding="utf-8") as stream:
                data = json.load(stream)
                if isinstance(data, dict):
                    profiles.update(data)
        except Exception:
            pass
    return profiles


def save_profiles(profiles: dict[str, dict]):
    f = get_profiles_file()
    with f.open("w", encoding="utf-8") as stream:
        json.dump(profiles, stream, indent=2)


def get_active_profile_id() -> str:
    sf = get_state_file()
    if sf.exists():
        try:
            with sf.open("r", encoding="utf-8") as stream:
                data = json.load(stream)
                return data.get("active_profile", "stock")
        except Exception:
            pass
    sys_f = get_system_state_file()
    if sys_f.exists():
        try:
            with sys_f.open("r", encoding="utf-8") as stream:
                data = json.load(stream)
                return data.get("active_profile", "stock")
        except Exception:
            pass
    return "stock"


def set_active_profile_id(profile_id: str):
    sf = get_state_file()
    try:
        with sf.open("w", encoding="utf-8") as stream:
            json.dump({"active_profile": profile_id}, stream, indent=2)
    except Exception:
        pass

    try:
        sys_dir = Path("/etc/nvidia-tune")
        sys_dir.mkdir(parents=True, exist_ok=True)
        sys_f = get_system_state_file()
        with sys_f.open("w", encoding="utf-8") as stream:
            json.dump({"active_profile": profile_id}, stream, indent=2)
    except Exception:
        pass


def apply_profile(profile_id: str) -> dict:
    profiles = load_profiles()
    if profile_id not in profiles:
        return {"success": False, "error": f"Profile '{profile_id}' not found"}

    p = profiles[profile_id]
    core_min = int(p.get("core_min", 210))
    core_max = int(p.get("core_max", 0))
    mem_offset = int(p.get("mem_offset", 0))
    power_limit = int(p.get("power_limit", 220))

    try:
        with NVMLClient() as client:
            client.set_power_limit_w(power_limit)
            if core_max > 0:
                client.set_gpu_locked_clocks(core_min, core_max)
            else:
                client.reset_gpu_locked_clocks()
            client.set_mem_offset_mhz(mem_offset)

        set_active_profile_id(profile_id)
        return {
            "success": True,
            "active_profile": profile_id,
            "profile": p,
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


def get_status() -> dict:
    profiles = load_profiles()
    active_id = get_active_profile_id()
    active_profile = profiles.get(active_id, DEFAULT_PROFILES["stock"])

    try:
        with NVMLClient() as client:
            used_mb, total_mb, free_mb = client.get_vram()
            gpu_util, mem_util = client.get_utilization()
            min_pl, max_pl = client.get_power_constraints_w()

            status = {
                "success": True,
                "gpu": {
                    "name": client.get_name(),
                    "driver_version": client.get_driver_version(),
                },
                "metrics": {
                    "temperature": client.get_temperature(),
                    "power_w": client.get_power_usage_w(),
                    "power_limit_w": client.get_power_limit_w(),
                    "min_power_limit_w": min_pl,
                    "max_power_limit_w": max_pl,
                    "core_clock_mhz": client.get_core_clock_mhz(),
                    "mem_clock_mhz": client.get_memory_clock_mhz(),
                    "mem_offset_mhz": client.get_mem_offset_mhz(),
                    "fan_speed_pct": client.get_fan_speed_pct(),
                    "gpu_utilization_pct": gpu_util,
                    "mem_utilization_pct": mem_util,
                    "vram_used_mb": used_mb,
                    "vram_total_mb": total_mb,
                    "vram_free_mb": free_mb,
                },
                "active_profile_id": active_id,
                "active_profile": active_profile,
                "is_tuned": active_id != "stock",
                "profiles": list(profiles.values()),
            }
            return status
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "active_profile_id": active_id,
            "active_profile": active_profile,
            "profiles": list(profiles.values()),
        }


def main():
    parser = argparse.ArgumentParser(description="NVIDIA RTX GPU Tuning CLI & NVML Controller")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # status
    subparsers.add_parser("status", help="Get live GPU metrics and active profile JSON")

    # apply
    apply_parser = subparsers.add_parser("apply", help="Apply a profile by ID")
    apply_parser.add_argument("profile_id", help="ID of profile to apply")

    # apply-boot
    subparsers.add_parser("apply-boot", help="Apply last active profile on boot")

    # toggle
    subparsers.add_parser("toggle", help="Toggle between tuned and stock profiles")

    # save
    save_parser = subparsers.add_parser("save-profile", help="Create or update a custom profile")
    save_parser.add_argument("id", help="Unique profile ID slug (e.g. gaming-max)")
    save_parser.add_argument("name", help="Display name")
    save_parser.add_argument("core_max", type=int, help="Core max clock in MHz (0 for uncapped)")
    save_parser.add_argument("mem_offset", type=int, help="VRAM offset in MHz (0-1200)")
    save_parser.add_argument("power_limit", type=int, help="Power limit in Watts (100-240)")
    save_parser.add_argument("--core-min", type=int, default=210, help="Core min clock (default: 210)")
    save_parser.add_argument("--desc", default="", help="Profile description")

    # delete
    del_parser = subparsers.add_parser("delete-profile", help="Delete a custom profile")
    del_parser.add_argument("id", help="Profile ID to delete")

    args = parser.parse_args()

    if args.command == "status":
        print(json.dumps(get_status(), indent=2))
    elif args.command == "apply":
        res = apply_profile(args.profile_id)
        print(json.dumps(res, indent=2))
        if not res.get("success"):
            sys.exit(1)
    elif args.command == "apply-boot":
        active_id = get_active_profile_id()
        res = apply_profile(active_id)
        print(json.dumps(res, indent=2))
        if not res.get("success"):
            sys.exit(1)
    elif args.command == "toggle":
        active_id = get_active_profile_id()
        target_id = "stock" if active_id != "stock" else "tuned"
        res = apply_profile(target_id)
        print(json.dumps(res, indent=2))
        if not res.get("success"):
            sys.exit(1)
    elif args.command == "save-profile":
        profiles = load_profiles()
        profiles[args.id] = {
            "id": args.id,
            "name": args.name,
            "description": args.desc or f"Core: {args.core_max} MHz, Mem: +{args.mem_offset} MHz, Power: {args.power_limit} W",
            "core_min": args.core_min,
            "core_max": args.core_max,
            "mem_offset": args.mem_offset,
            "power_limit": args.power_limit,
            "is_system": False,
        }
        save_profiles(profiles)
        print(json.dumps({"success": True, "saved_profile": profiles[args.id]}, indent=2))
    elif args.command == "delete-profile":
        profiles = load_profiles()
        if args.id in DEFAULT_PROFILES:
            print(json.dumps({"success": False, "error": "Cannot delete built-in system profiles"}, indent=2))
            sys.exit(1)
        if args.id in profiles:
            del profiles[args.id]
            save_profiles(profiles)
            print(json.dumps({"success": True, "deleted": args.id}, indent=2))
        else:
            print(json.dumps({"success": False, "error": "Profile not found"}, indent=2))
            sys.exit(1)


if __name__ == "__main__":
    main()
