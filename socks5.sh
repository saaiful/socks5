#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to URL-encode username and password
url_encode() {
    local raw="$1"
    local encoded=""
    for (( i=0; i<${#raw}; i++ )); do
        char="${raw:i:1}"
        case "$char" in
            [a-zA-Z0-9._~-]) encoded+="$char" ;;
            *) encoded+=$(printf '%%%02X' "'$char") ;;
        esac
    done
    echo "$encoded"
}

# Check if danted is installed
if command -v danted &> /dev/null; then
    echo -e "${GREEN}Dante SOCKS5 server is already installed.${NC}"
    echo -e "${CYAN}Do you want to (1) Reconfigure, (2) Add a new user, (3) Uninstall, or (4) Exit? (Enter 1, 2, 3, or 4):${NC}"
    read choice
    if [[ "$choice" == "1" ]]; then
        echo -e "${CYAN}Reconfiguring requires a port. Please enter the port for the SOCKS5 proxy (default: 1080):${NC}"
        read port
        port=${port:-1080}
        if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
            echo -e "${RED}Invalid port. Please enter a number between 1 and 65535.${NC}"
            exit 1
        fi
        reconfigure=true
        add_user=false
    elif [[ "$choice" == "2" ]]; then
        echo -e "${CYAN}Adding a new user...${NC}"
        reconfigure=false
        add_user=true
    elif [[ "$choice" == "3" ]]; then
        echo -e "${YELLOW}Uninstalling Dante SOCKS5 server...${NC}"
        sudo systemctl stop danted
        sudo systemctl disable danted
        sudo apt remove --purge dante-server -y
        sudo rm -f /etc/danted.conf /var/log/danted.log
        echo -e "${GREEN}Dante SOCKS5 server has been uninstalled successfully.${NC}"
        exit 0
    else
        echo -e "${YELLOW}Exiting.${NC}"
        exit 0
    fi
else
    echo -e "${YELLOW}Dante SOCKS5 server is not installed on this system.${NC}"
    echo -e "${CYAN}Note: Port 1080 is commonly used for SOCKS5 proxies. However, it may be blocked by your ISP or server provider. If this happens, choose an alternate port.${NC}"
    echo -e "${CYAN}Please enter the port for the SOCKS5 proxy (default: 1080):${NC}"
    read port
    port=${port:-1080}
    if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        echo -e "${RED}Invalid port. Please enter a number between 1 and 65535.${NC}"
        exit 1
    fi
    reconfigure=true
    add_user=true
fi

# Install or Reconfigure Dante
if [[ "$reconfigure" == "true" ]]; then
    sudo apt update -y
    sudo apt install dante-server curl -y
    echo -e "${GREEN}Dante SOCKS5 server installed successfully.${NC}"

    # Create the log file before starting the service
    sudo touch /var/log/danted.log
    sudo chown nobody:nogroup /var/log/danted.log

    # Automatically detect the primary network interface
    primary_interface=$(ip route | grep default | awk '{print $5}')
    if [[ -z "$primary_interface" ]]; then
        echo -e "${RED}Could not detect the primary network interface. Please check your network settings.${NC}"
        exit 1
    fi

    # Create the configuration file
    sudo bash -c "cat <<EOF > /etc/danted.conf
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = $port
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

    # Configure firewall rules
    if sudo ufw status | grep -q "Status: active"; then
        if ! sudo ufw status | grep -q "$port/tcp"; then
            sudo ufw allow "$port/tcp"
        fi
    fi

    if ! sudo iptables -L | grep -q "tcp dpt:$port"; then
        sudo iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
    fi

    # Edit the systemd service file for danted
    sudo sed -i '/\[Service\]/a ReadWriteDirectories=/var/log' /usr/lib/systemd/system/danted.service

    # Reload the systemd daemon and restart the service
    sudo systemctl daemon-reload
    sudo systemctl restart danted
    sudo systemctl enable danted

    # Check if the service is active
    if systemctl is-active --quiet danted; then
        echo -e "${GREEN}\nSocks5 server has been reconfigured and is running on port - $port${NC}"
    else
        echo -e "${RED}\nFailed to start the Socks5 server. Please check the logs for more details: /var/log/danted.log${NC}"
        exit 1
    fi
fi

# Add user
if [[ "$add_user" == "true" ]]; then
    echo -e "${CYAN}Please enter the username for the SOCKS5 proxy:${NC}"
    read username
    echo -e "${CYAN}Please enter the password for the SOCKS5 proxy:${NC}"
    read -s password
    if id "$username" &>/dev/null; then
        echo -e "${YELLOW}User @$username already exists. Updating password.${NC}"
    else
        sudo useradd --shell /usr/sbin/nologin "$username"
        echo -e "${GREEN}User @$username created successfully.${NC}"
    fi
    echo "$username:$password" | sudo chpasswd
    echo -e "${GREEN}Password updated successfully for user: $username.${NC}"
fi

# Test the SOCKS5 proxy
if [[ "$add_user" == "true" ]]; then
    echo -e "${CYAN}\nTesting the SOCKS5 proxy with curl...${NC}"
    proxy_ip=$(hostname -I | awk '{print $1}')
    encoded_username=$(url_encode "$username")
    encoded_password=$(url_encode "$password")

    curl -x socks5://"$encoded_username":"$encoded_password"@"$proxy_ip":"$port" https://ipinfo.io/

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}\nSOCKS5 proxy test successful. Proxy is working.${NC}"
    else
        echo -e "${RED}\nSOCKS5 proxy test failed. Please check your configuration.${NC}"
    fi
fi
