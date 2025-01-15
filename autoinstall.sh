#!/bin/bash

# Logging Functions
log() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
    exit 1
}

# Variables
DOWNLOAD_URL="https://github.com/hemilabs/heminetwork/releases/download/v0.11.0/heminetwork_v0.11.0_linux_amd64.tar.gz"
HOME_DIR="$HOME/heminetwork_v0.11.0_linux_amd64"
ENV_FILE="$HOME_DIR/.env"

# Install Docker if necessary
check_and_install_docker() {
    log "Checking if Docker is installed..."
    if ! command -v docker &> /dev/null; then
        log "Docker is not installed. Installing Docker..."
        sudo apt update || error "Failed to update package lists."
        sudo apt install -y docker.io || error "Failed to install Docker."
        sudo systemctl enable docker || error "Failed to enable Docker service."
        sudo systemctl start docker || error "Failed to start Docker service."
        success "Docker installed successfully."
    else
        success "Docker is already installed."
    fi
}

# Install the miner
# Install the miner
install_miner() {
    log "Checking for existing installation of Hemi PoP Miner..."
    if [ -d "$HOME_DIR" ]; then
        log "Existing installation found. Removing it..."
        rm -rf "$HOME_DIR" || error "Failed to remove existing installation at $HOME_DIR."
        log "Existing installation removed successfully."
    fi

    log "Creating directory for Hemi PoP Miner..."
    mkdir -p "$HOME_DIR" || error "Failed to create directory $HOME_DIR."

    log "Downloading the Hemi PoP Miner..."
    curl -L "$DOWNLOAD_URL" -o "$HOME_DIR/heminetwork.tar.gz" || error "Failed to download the miner."

    log "Extracting the miner files..."
    tar -xzf "$HOME_DIR/heminetwork.tar.gz" -C "$HOME_DIR" --strip-components=1 || error "Failed to extract the miner files."

    log "Setting executable permissions for binaries..."
    chmod +x "$HOME_DIR"/* || log "No binary files to make executable."

    success "Miner installed successfully in $HOME_DIR."
}


# Configure environment variables
configure_env() {
    log "Configuring environment variables..."
    
    # Ensure the directory exists
    if [ ! -d "$HOME_DIR" ]; then
        log "The directory $HOME_DIR does not exist. Creating it..."
        mkdir -p "$HOME_DIR" || error "Failed to create directory $HOME_DIR."
    fi

    # Check if .env file exists
    if [ ! -f "$ENV_FILE" ]; then
        log "Creating .env file at $ENV_FILE..."
        touch "$ENV_FILE" || error "Failed to create .env file at $ENV_FILE."
    fi

    # Prompt for environment variables
    read -sp "Enter your EVM Private Key: " EVM_PRIVKEY
    echo ""
    read -sp "Enter your Bitcoin Private Key: " POPM_BTC_PRIVKEY
    echo ""
    read -p "Enter your desired static fee (default: 50 sats/vB): " POPM_STATIC_FEE
    POPM_STATIC_FEE=${POPM_STATIC_FEE:-50}

    # Write environment variables to .env file
    {
        echo "POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public"
        echo "POPM_BTC_PRIVKEY=$POPM_BTC_PRIVKEY"
        echo "EVM_PRIVKEY=$EVM_PRIVKEY"
        echo "POPM_STATIC_FEE=$POPM_STATIC_FEE"
    } > "$ENV_FILE"

    success "Environment variables configured successfully and saved to $ENV_FILE."
}


# Start the miner
start_miner() {
    log "Starting the PoP Miner..."
    
    # Ensure the logs directory exists
    LOG_DIR="$HOME_DIR/logs"
    mkdir -p "$LOG_DIR" || error "Failed to create logs directory at $LOG_DIR."
    LOG_FILE="$LOG_DIR/hemi.logs"

    # Navigate to the miner directory and start the miner
    cd "$HOME_DIR" || error "Failed to navigate to the miner directory."
    export $(grep -v '^#' "$ENV_FILE" | xargs)
    nohup ./popmd > "$LOG_FILE" 2>&1 &
    if [ $? -ne 0 ]; then
        error "Failed to start the PoP Miner."
    fi
    
    success "PoP Miner started successfully. Logs are being saved to $LOG_FILE."
}

# Check logs
check_logs() {
    LOG_FILE="$HOME_DIR/logs/hemi.logs"
    if [ ! -f "$LOG_FILE" ]; then
        warning "No log file found at $LOG_FILE. Start the miner to generate logs."
        return
    fi
    log "Displaying the last 20 lines of the log file ($LOG_FILE):"
    tail -n 20 "$LOG_FILE"
    read -p "Press Enter to continue viewing logs, or Ctrl+C to exit..."
    less "$LOG_FILE"
}


# Uninstall the miner
uninstall_miner() {
    log "Uninstalling Hemi PoP Miner..."
    if [ -d "$HOME_DIR" ]; then
        rm -rf "$HOME_DIR" || error "Failed to remove $HOME_DIR."
        success "Hemi PoP Miner files removed from $HOME_DIR."
    else
        warning "Hemi PoP Miner is not installed."
    fi
}


# Stop the miner
stop_miner() {
    log "Stopping the PoP Miner..."
    PIDS=$(pgrep -f "./popmd")
    
    if [ -z "$PIDS" ]; then
        warning "No running PoP Miner process found."
        return
    fi

    for PID in $PIDS; do
        log "Stopping PoP Miner process with PID $PID..."
        kill "$PID" || error "Failed to stop the PoP Miner process with PID $PID."
    done

    success "All PoP Miner processes have been stopped."
}



# Main menu
main_menu() {
    clear
    curl -s https://raw.githubusercontent.com/dwisyafriadi2/logo/main/logo.sh | bash
    log "Welcome to the Hemi PoP Miner Installer!"
    echo "1. Install the Miner"
    echo "2. Configure Environment Variables"
    echo "3. Start the PoP Miner"
    echo "4. Stop the PoP Miner"
    echo "5. Install Docker (if not installed)"
    echo "6. Uninstall the Miner"
    echo "7. Check Logs"
    echo "8. Exit"
    
    read -p "Select an option (1-8): " choice
    case $choice in
        1) install_miner ;;
        2) configure_env ;;
        3) start_miner ;;
        4) stop_miner ;;
        5) check_and_install_docker ;;
        6) uninstall_miner ;;
        7) check_logs ;;
        8) success "Goodbye!"; exit 0 ;;
        *) warning "Invalid option. Please select a valid choice." ;;
    esac
    read -p "Press Enter to return to the main menu..."
    main_menu
}


# Start the script
main_menu
