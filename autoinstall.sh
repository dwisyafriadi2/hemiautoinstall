#!/bin/bash

# Function to print the banner
print_banner() {
  echo """
    ____                       
   / __ \\____ __________ ______
  / / / / __ \`/ ___/ __ \`/ ___/
 / /_/ / /_/ (__  ) /_/ / /    
/_____/_\\__,_/____/\\__,_/_/     

    ____                       __
   / __ \\___  ____ ___  __  __/ /_  ______  ____ _
  / /_/ / _ \\/ __ \`__ \\/ / / / / / / / __ \\/ __ \`/
 / ____/  __/ / / / / / /_/ / / /_/ / / / / /_/ / 
/_/    \\___/_/ /_/ /_/\\__,_/_/\\__,_/_/ /_/\\__, /  
                                         /____/    

====================================================
     Automation         : Auto Install Node Hemi
     Telegram Channel   : @dasarpemulung
     Telegram Group     : @parapemulung
====================================================
"""
}

# Call the print_banner function
print_banner

# Determine the appropriate home directory based on user
if [ "$EUID" -eq 0 ]; then
    USER_HOME="/root"
else
    USER_HOME="/home/$(whoami)"
fi

# Define variables using the user's home directory
DOWNLOAD_URL="https://github.com/hemilabs/heminetwork/releases/download/v0.5.0/heminetwork_v0.5.0_linux_amd64.tar.gz"
DOWNLOAD_FILE="$USER_HOME/heminetwork_v0.5.0_linux_amd64.tar.gz"
EXTRACT_DIR="$USER_HOME/heminetwork_v0.5.0_linux_amd64"
KEYGEN_OUTPUT="$USER_HOME/popm-address.json"
SERVICE_FILE="/etc/systemd/system/hemipopminer.service"

# Remove existing download file and extraction folder if they exist
if [ -f "$DOWNLOAD_FILE" ]; then
    echo "Removing existing download file $DOWNLOAD_FILE..."
    rm -f "$DOWNLOAD_FILE"
fi

if [ -d "$EXTRACT_DIR" ]; then
    echo "Removing existing directory $EXTRACT_DIR..."
    rm -rf "$EXTRACT_DIR"
fi

# Check if jq is installed, install if necessary
if ! command -v jq &> /dev/null; then
    echo "jq not found. Installing jq..."
    sudo apt update && sudo apt install -y jq
fi

# Step 1: Download the file
echo "Downloading Hemi Network binary..."
curl -L $DOWNLOAD_URL -o $DOWNLOAD_FILE

# Check if the file downloaded successfully
if [ ! -f $DOWNLOAD_FILE ]; then
    echo "Error: Download failed. Please check the URL and network connection."
    exit 1
fi

# Step 2: Extract the downloaded file
echo "Extracting Hemi Network binary..."
mkdir -p $EXTRACT_DIR
tar -xzvf $DOWNLOAD_FILE -C $USER_HOME

# Verify extracted files
echo "Verifying extracted files..."
ls -l $EXTRACT_DIR

# Verify that keygen exists after extraction
if [ ! -f $EXTRACT_DIR/keygen ]; then
    echo "Error: keygen executable not found in $EXTRACT_DIR. Extraction may have failed."
    echo "Contents of $EXTRACT_DIR:"
    ls -la $EXTRACT_DIR  # List contents for diagnostic purposes
    exit 1
fi

# Ensure keygen is executable
chmod +x $EXTRACT_DIR/keygen

# Step 3: Generate the address
echo "Generating address..."
if $EXTRACT_DIR/keygen -secp256k1 -json -net="testnet" > $KEYGEN_OUTPUT; then
    echo "Address generated at $KEYGEN_OUTPUT"
else
    echo "Error: keygen executable failed to run."
    exit 1
fi

# Step 4: Extract the private key
PRIVATE_KEY=$(jq -r '.private_key' $KEYGEN_OUTPUT)
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: Private key not found in $KEYGEN_OUTPUT"
    exit 1
fi

# Display the generated address details
cat $KEYGEN_OUTPUT

# Step 5: Create systemd service for hemipopminer
echo "Creating systemd service for hemipopminer..."
cat << EOF | sudo tee $SERVICE_FILE
[Unit]
Description=Hemi Network hemipopminer Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$EXTRACT_DIR
Environment="POPM_BTC_PRIVKEY=$PRIVATE_KEY"
Environment="POPM_STATIC_FEE=50"
Environment="POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public"
ExecStart=$EXTRACT_DIR/popmd
Restart=always
User=$(whoami)

[Install]
WantedBy=multi-user.target
EOF

# Step 6: Reload systemd, enable and start the hemipopminer service
sudo systemctl daemon-reload
sudo systemctl enable hemipopminer
sudo systemctl start hemipopminer

echo "hemipopminer service has been installed and started."
echo "Use 'systemctl status hemipopminer' to check the service status."

