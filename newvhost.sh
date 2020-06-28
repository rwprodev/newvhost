#!/bin/bash
# This script is used to create a new virtual host on CentOS 8.
# SELinux permissions are set.
# Let's Encrypt SSL Certificate is installed.
# Created by Carl Newlands
# Free to modify under MIT License
#
# Check for root user
if [ "$(whoami)" != 'root' ]; then
echo "You have to execute this script as root user"
exit 1;
fi
# Get new vhost details
read -p "Enter the top level domain name (e.g. example.com) : " domain
read -p "Enter a CNAME (e.g. www or dev) [optional] : " cname
read -p "Enter the path to the domain directory (default: /var/www/) : " path
path=${path:=/var/www/} # If empty, set default
[[ "${path}" != */ ]] && path="${path}/" # Add trailing / if needed
read -p "Enter the user you wanna use (e.g. : apache) : " user
read -p "Enter the listened IP for the server (default : *): " listen
listen=${listen:=*} # If empty, set default

alias=$cname.$domain
dir=$path$cname.$domain
if [[ "${cname}" == "" ]]; then
dir=$path$domain
alias=$domain
fi

echo "Create directory $dir for user $user [y/n]?"
read q
if [[ "${q}" == "yes" ]] || [[ "${q}" == "y" ]]; then

# Create vhost directory
if [ -d "$dir" ]
then
echo "Web directory already exists!"
exit 1;
else
mkdir -p $dir/html
mkdir -p $dir/log
echo "Web directory $dir created successfully!"
fi

# Create default web page
echo "<?php echo '<h1>$alias</h1>'; ?>" > $dir/html/index.php
chown -R $user:$user $dir/html
chmod -R '755' $dir

# Create virtual host
echo "### $alias
<VirtualHost $listen:80>
    ServerName $domain
    ServerAlias $alias
    RewriteEngine on
    RewriteCond %{SERVER_NAME} =$alias
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>
<VirtualHost *:443>
    ServerName $domain
    ServerAlias $alias
    DocumentRoot $dir/html
    ErrorLog $dir/log/error.log
    CustomLog $dir/log/requests.log combined

</VirtualHost>" > /etc/httpd/conf.d/$alias.conf
if ! echo -e /etc/httpd/conf.d/$alias.conf; then
echo "Virtual host $alias not created!"
exit 1;
else
echo "Virtual host $alias created!"
echo "Set SELinux Permissions [y/n]?"
read q
if [[ "${q}" == "yes" ]] || [[ "${q}" == "y" ]]; then
semanage fcontext -a -t httpd_log_t "$dir/log(/.*)?"
restorecon -R -v $dir/log
echo "Restarting Apache"
systemctl restart httpd
else
exit 1;
fi
fi

echo "Create Let's Encrypt Certificate [y/n]?"
read q
if [[ "${q}" == "yes" ]] || [[ "${q}" == "y" ]]; then
certbot-auto --apache -d $alias
echo "Restarting Apache"
systemctl restart httpd
else
exit 1;
fi
fi
