#!/bin/bash
git clone -b v3.9.3  https://github.com/intel/multus-cni.git                                      

# Determine the Operating System
OS="$(uname -s)"

# Define the file path
FILE_PATH="./multus-cni/deployments/multus-daemonset.yml"

# Check if the file exists
if [ ! -f "$FILE_PATH" ]; then
    echo "File does not exist: $FILE_PATH"
    exit 1
fi

# Execute the appropriate sed command based on the OS
case "$OS" in
    Darwin) # macOS
        echo "Running on macOS"
        sed -i '' 's/stable/v3.9.3/g' "$FILE_PATH"
        ;;
    Linux) # Assuming Linux implies Ubuntu or other distributions
        echo "Running on Linux"
        sed -i 's/stable/v3.9.3/g' "$FILE_PATH"
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
esac

echo "sed operation completed successfully."

#   sed -i 's/multus-conf-file=auto/multus-conf-file=\/tmp\/multus-conf\/70-multus.conf/g'           
#  /home/ubuntu/multus-cni/deployments/multus-daemonset.yml                                               
kubectl apply -f ./multus-cni/deployments/multus-daemonset.yml
