#!/bin/bash

USERNAME=linux-rdp

# Setup storage bind mount
mount --bind /storage /home/${USERNAME}/storage || true

echo "Chrome Remote Desktop Setup"
echo "============================"
echo ""
echo "Please visit http://remotedesktop.google.com/headless"
echo "and copy the command after Authentication"
echo ""
read -p "Paste the CRD command here: " CRP
echo ""
read -p "Enter a PIN for CRD (6 or more digits): " Pin
echo ""

# Run CRD setup as the linux-rdp user
su - ${USERNAME} -c "$CRP --pin=$Pin"

# Start chrome-remote-desktop service
service chrome-remote-desktop start

echo ""
echo "RDP setup completed successfully!"
echo "You can now connect via Chrome Remote Desktop"
echo ""

# Keep-alive loop
echo "Container is running. Press Ctrl+C to stop."
while true; do
    echo "I'm alive - $(date)"
    sleep 300  # Sleep for 5 minutes
done

