#!/usr/bin/env python3
"""pipe-send.py - Send a command to a named agent via Named Pipe."""
import sys, time

def main():
    if len(sys.argv) < 3:
        print("Usage: pipe-send.py <id> <message> [timeout_ms]", file=sys.stderr)
        sys.exit(1)

    agent_id = sys.argv[1]
    message = sys.argv[2]
    timeout_ms = int(sys.argv[3]) if len(sys.argv) > 3 else 5000

    pipe_path = rf"\\.\pipe\claude_agent_{agent_id}"

    try:
        start = time.time()
        with open(pipe_path, "w") as f:
            f.write(message)
        elapsed = (time.time() - start) * 1000
        print(f"[OK -> {agent_id}] {message}")
    except FileNotFoundError:
        print(f"[错误 -> {agent_id}] Pipe not found (agent offline?)", file=sys.stderr)
        sys.exit(1)
    except OSError as e:
        print(f"[错误 -> {agent_id}] {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
