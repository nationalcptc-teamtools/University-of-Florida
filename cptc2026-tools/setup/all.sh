sudo apt update
sudo apt install -y asciinema sliver

# --- ASCIINEMA ---
# Will only be run once
if ! grep -q "Auto-start asciinema recording" ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc << 'EOF'

# Auto-start asciinema recording
if [[ $- == *i* ]] && [[ -z "$ASCIINEMA_REC" ]] && command -v asciinema &> /dev/null; then
    # Set recording directory
    RECORDING_DIR="$HOME/asciinema-recordings"
    
    # Create directory if it doesn't exist
    mkdir -p "$RECORDING_DIR"
    
    # Generate filename with timestamp
    RECORDING_FILE="$RECORDING_DIR/session-$(date +%Y%m%d-%H%M%S).cast"
    
    # Set environment variable to prevent nested recordings
    export ASCIINEMA_REC=1
    
    # Start recording
    asciinema rec "$RECORDING_FILE"
    
    # Exit the shell when recording stops
    exit
fi
EOF
fi

echo
echo
echo "Setup complete... Please restart your shell!"
