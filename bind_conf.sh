#!/bin/bash

# Copyright (C) 2024 Merras
# Made by Merras.


apt update -y >/dev/null 2>&1
apt install bind9 -y >/dev/null 2>&1
apt install pv -y >/dev/null 2>&1

if grep -q "iface enp0s8 inet static" /etc/network/interfaces; then
    ip=$(grep -Po "(?<=address )(\d+\.\d+\.\d+\.\d+)" /etc/network/interfaces)
fi

echo
echo "Put the subdomain to be used in the BIND9 configuration:"
read subdomain
echo "Put the Domain name to be used in the BIND9 configuration:"
read dns

cd /etc/bind/
config_file="named.conf.options"

echo "Please, Put the IP Address to configure the forwarders:"
read forwarder_ip

echo "Updating the config file..."
sed -i "s|// forwarders {|forwarders {\n\t\t$forwarder_ip;|g" "$config_file"
sed -i 's|// \t0.0.0.0;|    |g' "$config_file"
sed -i 's|// };|};|g' "$config_file"
echo "The configuration has been updated. The IP address $forwarder_ip has been saved into the forwarders."
echo

echo "zone ""\"$dns\"" "{" >> named.conf.local
echo "  type master;" >> named.conf.local
echo "  allow-query { any; };" >> named.conf.local
echo "  allow-transfer { any; };" >> named.conf.local
echo '  file "/etc/bind/db.'$dns'";' >> named.conf.local
echo "};" >> named.conf.local
echo

sed -i -E "s/^nameserver 192\.168\.[0-9]+\.[0-9]+$/nameserver $ip/" /etc/resolv.conf

touch db.$dns
echo '$TTL 1D' >> db.$dns
echo ""$dns". IN        SOA     "$subdomain'.'$dns". admin."$dns".(" >> db.$dns
echo "  777     ;Serial" >> db.$dns
echo "  604800  ;Refresh" >> db.$dns
echo "  86400   ;Retry" >> db.$dns
echo "  2419200 ;Expire" >> db.$dns
echo "  10800   ;Negative cache" >> db.$dns
echo ")" >> db.$dns
echo "" >> db.$dns
echo "@ IN      NS      "$subdomain'.'$dns'.' >> db.$dns
echo "" >> db.$dns
echo ""$subdomain"      IN      A       $ip" >> db.$dns
echo "Configuration made in" db.$dns "done succesfully."
echo

named-checkzone $dns db.$dns
systemctl restart bind9 >/dev/null 2>&1
