#!/bin/bash
# hook-stop.sh - Claude Code Stop hook
# Writes a .done signal file when an agent-managed Claude Code instance finishes a response.
# Non-agent sessions (no CLAUDE_AGENT_ID) are ignored.

[ -z "$CLAUDE_AGENT_ID" ] && exit 0

SIGNAL_DIR="C:/tmp/claude_agents/signals"
mkdir -p "$SIGNAL_DIR"

# Write done signal with timestamp (overwrite previous)
echo "{\"agent_id\":\"$CLAUDE_AGENT_ID\",\"event\":\"done\",\"time\":\"$(date -Iseconds)\"}" \
  > "$SIGNAL_DIR/$CLAUDE_AGENT_ID.done"

exit 0
