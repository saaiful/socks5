#!/bin/bash

echo -e "Please enter the username for the SOCKS5 proxy:"
read username
echo -e "Please enter the password for the SOCKS5 proxy:"
read -s password

# Update repositories
sudo apt update -y

# Install dante-server
sudo apt install dante-server -y

# Create the log file before starting the service
sudo touch /var/log/danted.log
sudo chown nobody:nogroup /var/log/danted.log

# Automatically detect the primary network interface
primary_interface=$(ip route | grep default | awk '{print $5}')
if [[ -z "$primary_interface" ]]; then
  echo "Could not detect the primary network interface. Please check your network settings."
  exit 1
fi

# Create the configuration file
sudo bash -c "cat <<EOF > /etc/danted.conf
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = 1080
external: $primary_interface
method: username
user.privileged: root
user.notprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
EOF"

# Add user with password
sudo useradd --shell /usr/sbin/nologin $username
echo "$username:$password" | sudo chpasswd

# Check if UFW is active and open port 1080 if needed
if sudo ufw status | grep -q "Status: active"; then
    sudo ufw allow 1080/tcp
fi

# Check if iptables is active and open port 1080 if needed
if sudo iptables -L | grep -q "ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:1080"; then
    echo "Port 1080 is already open in iptables."
else
    sudo iptables -A INPUT -p tcp --dport 1080 -j ACCEPT
fi

# Edit the systemd service file for danted with sed
sudo sed -i '/\[Service\]/a ReadWriteDirectories=/var/log' /usr/lib/systemd/system/danted.service

# Reload the systemd daemon to apply the changes
sudo systemctl daemon-reload

# Restart the danted service
sudo systemctl restart danted

# Enable danted to start at boot
sudo systemctl enable danted

# Display the detected interface for verification
echo "Dante SOCKS5 proxy is set up using the interface: $primary_interface"
