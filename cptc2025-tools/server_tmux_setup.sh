#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set the session name
SESSION_NAME="CPTC10"

# Paths to your scripts
SCRIPT1="$DIR/sliver-server-setup.sh"
SCRIPT2="$DIR/sliver-client-setup.sh"
chmod +x $SCRIPT1
chmod +x $SCRIPT2

# Start a new detached tmux session named 'my_session' with the first window
tmux new-session -d -s $SESSION_NAME -n 'SliverServer'

# In the first window, run script1.sh
tmux send-keys -t $SESSION_NAME:0 "$SCRIPT1" C-m

# Create the second window and run script2.sh
tmux new-window -t $SESSION_NAME:1 -n 'SliverClient'
tmux send-keys -t $SESSION_NAME:1 "$SCRIPT2" C-m

# Create the third window with a bash prompt
tmux new-window -t $SESSION_NAME:2 -n 'Bash'

# Attach to the tmux session
tmux attach-session -t $SESSION_NAME