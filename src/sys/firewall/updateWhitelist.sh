#!/bin/bash

. /usr/local/bin/common.sh


PATH=$PATH:/sbin:/usr/sbin


#iptables -I LCN -s "www.example.com" -j LCNACT
x=$(cat /etc/whitelist | sort | uniq |
           grep -Ee '^\s*(([a-zA-Z](-?[a-zA-Z0-9])*)\.)*[a-zA-Z](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}\s*$' |
           sed -re 's%^(.+)$%iptables -I LCN -s "\1" -j LCNACT%g')


#To avoid removing the existing whitelist if any read or parsing error ocurred
if [ "$x" ]; then 
  iptables -F LCN
  echo "$x" | sh
fi
