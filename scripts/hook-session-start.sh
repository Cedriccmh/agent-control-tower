#!/bin/bash
# hook-session-start.sh - Claude Code SessionStart hook
# Writes a .ready signal file when an agent-managed Claude Code instance starts.
# Non-agent sessions (no CLAUDE_AGENT_ID) are ignored.

[ -z "$CLAUDE_AGENT_ID" ] && exit 0

SIGNAL_DIR="C:/tmp/claude_agents/signals"
mkdir -p "$SIGNAL_DIR"

# Write ready signal with timestamp
echo "{\"agent_id\":\"$CLAUDE_AGENT_ID\",\"event\":\"ready\",\"time\":\"$(date -Iseconds)\"}" \
  > "$SIGNAL_DIR/$CLAUDE_AGENT_ID.ready"

exit 0
