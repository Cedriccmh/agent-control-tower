#!/usr/bin/env python3
"""pipe-cleanup.py - Gracefully shut down agents (/exit + kill process tree)."""
import json, os, glob, subprocess, sys, time

REG_DIR = r"C:\tmp\claude_agents"
SIGNAL_DIR = os.path.join(REG_DIR, "signals")

def send_via_pipe(pipe_name, message):
    """Send a message through Named Pipe. Returns True on success."""
    pipe_path = rf"\\.\pipe\{pipe_name}"
    try:
        with open(pipe_path, "w") as f:
            f.write(message)
        return True
    except (FileNotFoundError, OSError):
        return False

def kill_process_tree(pid):
    """Kill process tree using taskkill /T /F."""
    try:
        subprocess.run(
            ["taskkill", "/T", "/F", "/PID", str(pid)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
    except Exception:
        pass

def main():
    target_id = sys.argv[1] if len(sys.argv) > 1 else None

    if target_id:
        files = glob.glob(os.path.join(REG_DIR, f"{target_id}.json"))
    else:
        files = glob.glob(os.path.join(REG_DIR, "*.json"))

    if not files:
        print("没有在线的 agent。")
        return

    for f in sorted(files):
        try:
            info = json.load(open(f))
        except (json.JSONDecodeError, OSError):
            os.remove(f)
            continue

        agent_id = info["id"]

        # 1. Try graceful /exit via pipe
        if send_via_pipe(info["pipe"], "/exit"):
            print(f"[{agent_id}] 已发送 /exit")
            time.sleep(2)
        else:
            print(f"[{agent_id}] pipe 不可用，直接杀进程")

        # 2. Kill process tree
        kill_process_tree(info["pid"])
        print(f"[{agent_id}] 已杀掉进程树 (pid={info['pid']})")

        # 3. Clean up registration + signal files
        os.remove(f)
        for ext in (".ready", ".done"):
            sig = os.path.join(SIGNAL_DIR, f"{agent_id}{ext}")
            if os.path.exists(sig):
                os.remove(sig)

if __name__ == "__main__":
    main()
