#!/usr/bin/env bash

# Script to configure command logging for both Bash and Zsh shells

# Function to check if the script is run as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run this script as root."
        exit 1
    fi
}

# Function to prompt for the log directory
get_log_directory() {
    read -p "Enter the directory where you want to store the command logs: " log_dir
    # Remove any trailing slash
    log_dir="${log_dir%/}"
    if [ -z "$log_dir" ]; then
        echo "Log directory cannot be empty."
        exit 1
    fi
}

# Function to create the log directory and file
setup_log_directory() {
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
        echo "Created directory: $log_dir"
    fi
    log_file="$log_dir/command.log"
    if [ ! -f "$log_file" ]; then
        touch "$log_file"
        echo "Created log file: $log_file"
    fi
    chmod 777 "$log_file"
    echo "Set permissions on log file: $log_file"
}

# Function to update Bash configuration
update_bashrc() {
    bashrc_file="/etc/bash.bashrc"

    # Backup the original file if not already backed up
    if [ ! -f "${bashrc_file}.backup" ]; then
        cp "$bashrc_file" "${bashrc_file}.backup"
        echo "Backup created: ${bashrc_file}.backup"
    fi

    # Define the logging function for Bash
    logging_function_bash=$(cat <<EOF

# Command logging configuration for Bash
log_command_bash() {
    local exit_status=\$?
    local user=\$(whoami)
    local cmd=\$(history 1 | sed 's/^[ ]*[0-9]\+[ ]*//')
    local timestamp=\$(date '+%Y-%m-%d %H:%M:%S')
    echo "\$timestamp [User: \$user] [Exit: \$exit_status] Command: \$cmd" >> "$log_file"
}
export PROMPT_COMMAND=log_command_bash
# readonly PROMPT_COMMAND

EOF
)

    # Check if the logging function is already present
    if grep -q "Command logging configuration for Bash" "$bashrc_file"; then
        echo "Command logging for Bash is already configured in $bashrc_file."
    else
        echo "$logging_function_bash" >> "$bashrc_file"
        echo "Updated $bashrc_file with command logging configuration for Bash."
    fi
}

# Function to update Zsh configuration
update_zshrc() {
    zshrc_file="/etc/zsh/zshrc"

    # Backup the original file if not already backed up
    if [ ! -f "${zshrc_file}.backup" ]; then
        cp "$zshrc_file" "${zshrc_file}.backup"
        echo "Backup created: ${zshrc_file}.backup"
    fi

    # Define the logging function for Zsh
    logging_function_zsh=$(cat <<EOF

# Command logging configuration for Zsh
log_command_zsh() {
    local exit_status=\$?
    local user=\$(whoami)
    local cmd="\$1"
    local timestamp=\$(date '+%Y-%m-%d %H:%M:%S')
    echo "\$timestamp [User: \$user] [Exit: \$exit_status] Command: \$cmd" >> "$log_file"
}
preexec() { log_command_zsh "\$1"; }

EOF
)

    # Check if the logging function is already present
    if grep -q "Command logging configuration for Zsh" "$zshrc_file"; then
        echo "Command logging for Zsh is already configured in $zshrc_file."
    else
        echo "$logging_function_zsh" >> "$zshrc_file"
        echo "Updated $zshrc_file with command logging configuration for Zsh."
    fi
}

# Main script execution
main() {
    check_root
    get_log_directory
    setup_log_directory
    update_bashrc
    update_zshrc
    echo "Command logging has been configured successfully for Bash and Zsh."
}

main
