#!/bin/bash
 
func_package() {
  REQUIRED_PKG="mailutils"
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
  echo Checking for $REQUIRED_PKG: $PKG_OK
  if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    apt-get install mailutils;
  fi
}

func_log() {
  has=`iptables -L | grep LOG`;
  if [ ! $has ]; then
    echo "Adding LOG line in Iptables..."
    iptables -A INPUT -p tcp -m tcp --dport 22 --syn -j LOG --log-prefix "SSH connect"
  fi
}


func_search() {
  ip=$1
  for ipD in `iptables -L | grep DROP | awk '{ print $4 }' | egrep -v DROP`;
  do
    if [ "$ip" == "$ipD" ]; then
      return 
    fi
  done
  false
}

func_sendmail() {
  ip=$1
  echo "Sending email..."
  echo "Drop IP: $ip" | mail -s "Firewall Alert" naylorbachiega@gmail.com
  echo "mail sent"
}

################### MAIN ########################
func_package
func_log

#lista de ip
ips=`cat /var/log/syslog | grep "SSH connect"| awk  '{print $12}' | awk -F'=' '{print $2}'`

if [ -z "$ips" ]; then
  echo "No records found!"
  exit
fi

#cada ip fica em uma linha, conta numero de linhas
words=( $ips )
count=$((${#words[@]}))

for (( i=1; i<$count; i++ ))
 do
    ip=`cat /var/log/syslog | grep "SSH connect"| awk '(NR == '"$i"') {print $12}' | awk -F'=' '{print $2}'`

    if ! (func_search $ip); then
      echo "Drop the IP: $ip"
      iptables -A INPUT  -i enp0s8 -p tcp -s "$ip" --dport 22 -j DROP
      echo "IP inserted in Iptables"
      func_sendmail $ip
      sleep 2
    fi

 done

