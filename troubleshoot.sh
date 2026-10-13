#!/bin/bash
# Server Diagnostics Script
# This script automates user interaction to troubleshoot common network issues and how to fix this errors.

echo "=========================================================="
echo "      Welcome to the Network Troubleshooting Wizard       "
echo "=========================================================="
echo ""

# User interaction using the 'read' command for capture their answers too.
echo "Please select the type of server you are currently using:"
echo "1) CentOS "
echo "2) Ubuntu"
echo ""
read -p "Enter your choice (1 or 2): " option

echo ""
echo "----------------------------------------------------------"

# Conditional structure to evaluate user input and print the result
if [ "$option" = "1" ]; then
    echo "[!] Diagnostics selected for: CentOS"
    echo ""
    echo "1. No Internet Connectivity:"
    echo "   - Check if your network interface is active using: 'ip link'"
    echo "   - Try restarting the network manager service with: 'sudo systemctl restart NetworkManager'"
    echo ""
    echo "2. Setting a Static IP Address and DNS:"
    echo "   - In CentOS, network interface configuration files are located in: /etc/sysconfig/network-scripts/"
    echo "   - Edit your interface file (example, ifcfg-eth0) and ensure it contains:"
    echo "     BOOTPROTO=none"
    echo "     ONBOOT=yes"
    echo "     IPADDR=192.168.1.50"
    echo "     NETMASK=255.255.255.0"
    echo "     GATEWAY=192.168.1.1"
    echo "     DNS1=8.8.8.8"
    echo "   - Apply the changes using: 'nmcli connection reload'"

elif [ "$option" = "2" ]; then
    echo "[!] Diagnostics selected for: Ubuntu"
    echo ""
    echo "1. No Internet Connectivity:"
    echo "   - Review the status of your interfaces using: 'ip a'"
    echo "   - Attempt to bring up a disabled interface with: 'sudo ip link set dev <interface> up'"
    echo ""
    echo "2. Setting a Static IP Address and DNS:"
    echo "   - Modern Ubuntu utilizes Netplan. Navigate to: /etc/netplan/"
    echo "   - Modify the YAML configuration file (example, 01-netcfg.yaml) using this structure:"
    echo "     ethernets:"
    echo "       enp0s3:"
    echo "         dhcp4: no"
    echo "         addresses: [192.168.1.50/24]"
    echo "         gateway4: 192.168.1.1"
    echo "         nameservers:"
    echo "           addresses:"
    echo "   - Apply the new configuration with: 'sudo netplan apply'"

else
    # Error handling for unexpected user entries
    echo "[X] Error: Invalid option selected. Exiting script."
    exit 1
fi

echo "----------------------------------------------------------"
echo ""
echo "=== Automated General Diagnostics ==="
echo ""

# 3. DNS check by filtering the system's active nameservers
echo "[*] Checking current system DNS configuration..."
echo "Your /etc/resolv.conf file actively contains:"
cat /etc/resolv.conf | grep nameserver
echo ""

# 4. Running a network trace to a common website
echo "[*] Running a network trace (traceroute) to google.com to check routing hops..."
echo "(Note: If this command fails, make sure 'traceroute' or 'mtr' is installed)"
echo ""

# Executes a traceroute limited to a maximum of 10 hops for a quick diagnostic
traceroute -m 10 google.com

echo ""
echo "=========================================================="
echo " Troubleshooting complete. Please review the details above."
echo "=========================================================="
