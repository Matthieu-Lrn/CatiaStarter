import ctypes
import os
import shutil
import subprocess
import sys
import time
from ctypes import wintypes
from pathlib import Path


PLM_CHOOSER = Path(r"I:\cecc\bin\PLMStart.Chooser.tcl")
AUTO_START_TCL = Path(__file__).with_name("launch_catia_auto.tcl")
CATIA_MODE = "1"
DEFAULT_LEVEL = "PRD"
START_TIMEOUT_SECONDS = 90


user32 = ctypes.WinDLL("user32", use_last_error=True)
LRESULT = ctypes.c_longlong if ctypes.sizeof(ctypes.c_void_p) == 8 else ctypes.c_long

EnumWindowsProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
EnumChildProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

user32.EnumWindows.argtypes = [EnumWindowsProc, wintypes.LPARAM]
user32.EnumWindows.restype = wintypes.BOOL
user32.EnumChildWindows.argtypes = [wintypes.HWND, EnumChildProc, wintypes.LPARAM]
user32.EnumChildWindows.restype = wintypes.BOOL
user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.GetWindowTextW.restype = ctypes.c_int
user32.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.GetClassNameW.restype = ctypes.c_int
user32.IsWindowVisible.argtypes = [wintypes.HWND]
user32.IsWindowVisible.restype = wintypes.BOOL
user32.SetForegroundWindow.argtypes = [wintypes.HWND]
user32.SetForegroundWindow.restype = wintypes.BOOL
user32.SendMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
user32.SendMessageW.restype = LRESULT

BM_CLICK = 0x00F5


def window_text(hwnd):
    buffer = ctypes.create_unicode_buffer(512)
    user32.GetWindowTextW(hwnd, buffer, len(buffer))
    return buffer.value


def class_name(hwnd):
    buffer = ctypes.create_unicode_buffer(256)
    user32.GetClassNameW(hwnd, buffer, len(buffer))
    return buffer.value


def enum_top_windows():
    windows = []

    @EnumWindowsProc
    def callback(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            windows.append(hwnd)
        return True

    user32.EnumWindows(callback, 0)
    return windows


def enum_child_windows(parent):
    children = []

    @EnumChildProc
    def callback(hwnd, _):
        children.append(hwnd)
        return True

    user32.EnumChildWindows(parent, callback, 0)
    return children


def find_launcher_window():
    for hwnd in enum_top_windows():
        title = window_text(hwnd)
        normalized = title.strip().lower()
        if normalized.startswith("catstart v5"):
            return hwnd
        if normalized.startswith("plmstart") and "prd" in normalized:
            return hwnd
    return None


def click_start_button(parent):
    for child in enum_child_windows(parent):
        if window_text(child).strip().lower() == "start":
            user32.SetForegroundWindow(parent)
            user32.SendMessageW(child, BM_CLICK, 0, 0)
            return True
    return False


def read_saved_catia_env(settings_file):
    if not settings_file.exists():
        return None, DEFAULT_LEVEL, None

    raw = settings_file.read_text(encoding="utf-8", errors="ignore").strip()
    if not raw:
        return None, DEFAULT_LEVEL, raw

    parts = raw.split(":")
    env_name = parts[0].strip()
    tokens = env_name.split()

    level = DEFAULT_LEVEL
    for token in tokens:
        upper = token.upper()
        if upper in {"VLD", "CRT", "TRN", "PRD"}:
            level = upper
            break

    if len(tokens) == 2:
        level = "PRD"

    return env_name, level, raw


def force_saved_mode_to_catia(settings_file, original_raw):
    if not original_raw:
        return False

    parts = original_raw.split(":")
    if len(parts) < 2:
        parts.append(CATIA_MODE)
    else:
        if parts[1] == CATIA_MODE:
            return False
        parts[1] = CATIA_MODE

    settings_file.write_text(":".join(parts), encoding="utf-8")
    return True


def restore_saved_settings(settings_file, original_raw, changed):
    if changed and original_raw is not None:
        settings_file.write_text(original_raw, encoding="utf-8")


def find_wish():
    for candidate in (
        shutil.which("wish"),
        r"C:\tcl\bin\wish.exe",
        r"C:\Tcl\bin\wish.exe",
    ):
        if candidate and Path(candidate).exists():
            return candidate

    raise FileNotFoundError("Could not find wish.exe. Check that Tcl/Tk is installed and on PATH.")


def main():
    settings_file = Path(os.environ["USERPROFILE"]) / "catia.envV5"
    env_name, level, original_raw = read_saved_catia_env(settings_file)
    settings_changed = False

    if env_name:
        settings_changed = force_saved_mode_to_catia(settings_file, original_raw)

    launch_env = os.environ.copy()
    launch_env["PLMSTART_AUTO_LEVEL"] = level

    wish = find_wish()
    launch_script = AUTO_START_TCL if AUTO_START_TCL.exists() else PLM_CHOOSER
    process = subprocess.Popen([wish, str(launch_script)], env=launch_env)

    try:
        try:
            process.wait(timeout=START_TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            print("The PLM launcher did not finish auto-starting CATIA within {} seconds.".format(
                START_TIMEOUT_SECONDS
            ))
            return 2
    finally:
        restore_saved_settings(settings_file, original_raw, settings_changed)

    if process.returncode == 0:
        print("Started CATIA using level {}.".format(level))
        return 0

    print("The PLM launcher exited with code {}.".format(process.returncode))
    return process.returncode


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        sys.stderr.write("CATIA launch failed: {}\n".format(exc))
        raise SystemExit(1)
