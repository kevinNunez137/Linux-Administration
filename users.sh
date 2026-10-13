#!/bin/bash

# We going to start see who is online in the server right now.
read -p "Press enter to show active users in the server:"
w | tee -a Output.txt

# This is for showing the last 10 logs in the server, but the users need to exists for this.
echo Type the user name to see the last 10 Log in  registry:
read users
last -n 10 $users | tee -a Output.txt

# Now we going to see the user last activity.
echo Type the user name to see last 10 input commands:
read users
cat /home/$users/.bash_history |tail -10 |tee -a Output.txt

# Now we going to monitoring in our network, using network basic commands.
read -p"Networking information: Press enter"
netstat -a | head -20 | tee -a Output.txt

read -p"Networking  Ip and stuff: Press Enter"
ifconfig | tee -a Output.txt

# Now lets check webpages.
echo Type a webpage to analyze it:
read webpage
whois $webpage | tee -a Output.txt

# Now lets make a way to check the firewall status in the server.
read -p "Firewall open ports analysis: Press Enter"
firewall-cmd --list-all | less | tee -a Output.txt

read -p "Firewall status: Press Enter"
systemctl status firewalld | tee -a Output.txt
