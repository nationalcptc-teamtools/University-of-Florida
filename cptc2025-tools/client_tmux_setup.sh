#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set the session name
SESSION_NAME="CPTC10"

# Paths to your scripts
SCRIPT1="$DIR/sliver-client-setup.sh"
chmod +x $SCRIPT1

# Start a new detached tmux session named 'my_session' with the first window
tmux new-session -d -s $SESSION_NAME -n 'SliverClient'

# In the first window, run script1.sh
tmux send-keys -t $SESSION_NAME:0 "$SCRIPT1" C-m

# Create the second window with a bash prompt
tmux new-window -t $SESSION_NAME:1 -n 'Bash'

# Attach to the tmux session
tmux attach-session -t $SESSION_NAME