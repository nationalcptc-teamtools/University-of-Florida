sudo apt-get update
sudo apt-get install asciinema -y
sudo apt-get install sliver -y
sudo apt-get install seclists -y

# Will only be run once
grep -q "# Auto-start asciinema recording" ~/.zshrc || cat << 'EOF' >> ~/.zshrc
# Auto-start asciinema recording
if [[ $- == *i* ]] && [[ -z "\$ASCIINEMA_REC" ]] && command -v asciinema &> /dev/null; then
    # Set recording directory
    RECORDING_DIR="\$HOME/recordings"
    
    # Create directory if it doesn't exist
    mkdir -p "\$RECORDING_DIR"
    
    # Generate filename with timestamp
    RECORDING_FILE="\$RECORDING_DIR/session-\$(date +%Y%m%d-%H%M%S).cast"
    
    # Set environment variable to prevent nested recordings
    export ASCIINEMA_REC=1
    
    # Start recording
    asciinema rec "\$RECORDING_FILE"
    
    # Exit the shell when recording stops
    exit
fi
EOF
