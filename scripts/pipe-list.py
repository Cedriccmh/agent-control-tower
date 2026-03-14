#!/usr/bin/env python3
"""pipe-list.py - List all online agents (auto-cleanup dead ones)."""
import json, os, glob, subprocess, sys

REG_DIR = r"C:\tmp\claude_agents"

def is_process_alive(pid):
    """Check if a process is alive using tasklist."""
    try:
        output = subprocess.check_output(
            ["tasklist", "/FI", f"PID eq {pid}", "/NH"],
            text=True, stderr=subprocess.DEVNULL
        )
        return str(pid) in output
    except Exception:
        return False

def check_hooks():
    """Check if hooks are properly configured. Returns list of issues."""
    issues = []
    hooks_dir = os.path.join(os.environ.get("USERPROFILE", ""), ".claude", "hooks")
    for name in ("hook-session-start.sh", "hook-stop.sh"):
        if not os.path.exists(os.path.join(hooks_dir, name)):
            issues.append(f"missing {name}")
    settings = os.path.join(os.environ.get("USERPROFILE", ""), ".claude", "settings.json")
    if os.path.exists(settings):
        try:
            raw = open(settings).read()
            if '"SessionStart"' not in raw or '"Stop"' not in raw:
                issues.append("settings.json missing SessionStart/Stop hooks")
        except OSError:
            issues.append("cannot read settings.json")
    else:
        issues.append("settings.json not found")
    return issues

def main():
    files = glob.glob(os.path.join(REG_DIR, "*.json"))
    if not files:
        print("没有在线的 agent。")
    else:
        print("=== 在线 Agent ===")
        for f in sorted(files):
            try:
                info = json.load(open(f))
            except (json.JSONDecodeError, OSError):
                os.remove(f)
                continue

            if is_process_alive(info["pid"]):
                print(f"  [{info['id']}] pipe={info['pipe']}  pid={info['pid']}  started={info['startTime']}")
            else:
                os.remove(f)
                print(f"  [{info['id']}] (已离线，已清理)")

    # Hook status check
    issues = check_hooks()
    if issues:
        print(f"\n[!] Hook issue: {'; '.join(issues)}")
        print("    Ready/done signals won't work. See references/setup.md")

if __name__ == "__main__":
    main()
