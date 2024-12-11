# SOCKS5 Proxy Setup Script for Ubuntu

This repository contains a script that helps you to setup a SOCKS5 proxy server on an Ubuntu system. The server uses `dante-server` and supports username/password authentication.

## Prerequisites

- Ubuntu system (This script was tested on Ubuntu 20.04, but should work with other versions as well).
- User with `sudo` privileges.

## Features
- **Installation:** Installs dante-server and configures it with SOCKS5 authentication.
- **Reconfiguration:** Update port and settings dynamically.
- **User Management:** Add or update users with username/password authentication.
- **Testing:** Automatically tests the proxy after setup using `curl`.
- **Uninstallation:** Completely removes dante-server along with its configuration and logs.
- **Dynamic Network Interface Detection:** Automatically detects the primary network interface for seamless configuration.
- **Port Selection:** Allows specifying a custom port with validation.

## Installation
Run the script
```bash
wget https://raw.githubusercontent.com/saaiful/socks5/main/socks5.sh
sudo bash socks5.sh
```

You'll be prompted for a username and password. These will be the credentials for the SOCKS5 proxy.


## Testing the Proxy
The proxy can be tested from a Windows machine using `curl`. If you don't have curl installed, it can be installed with the following command:
```bash
apt-get install curl
```

## Uninstallation
To completely remove the SOCKS5 server, select the `Uninstall` option when running the script. This will stop the service, remove the package, and clean up all related configuration and log files.

You can then test the proxy with:
```
curl -x socks5://username:password@proxy_server_ip:1080 https://ifconfig.me
curl -x socks5://username:password@proxy_server_ip:1080 https://ipinfo.io
```
