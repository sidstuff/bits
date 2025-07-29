if curl -V &> /dev/null; then
  CMD='curl'
  FLAGS='-fsSL'
elif wget -V &> /dev/null; then
  CMD='wget'
  FLAGS='-qO-'
else
  echo "Neither curl nor wget found. Exiting..." >&2
  exit 1
fi
read -p "Username: " USERNAME
read -sp "Password: " PASSWORD
printf "\n"

# https://gist.github.com/cdown/1163649?permalink_comment_id=2157284
urlencode() { # Passwords can contain ampersands, etc.
  local LANG=C i c e=''
  for (( i=0; i<${#1}; i++ )); do
    c=${1:$i:1}
    [[ "$c" =~ [a-zA-Z0-9\.\~\_\-] ]] || printf -v c '%%%02X' "'$c"
    e+="$c"
  done
  echo "$e"
}

mkdir /etc/bits
cd /etc/bits

$CMD $FLAGS https://github.com/sidstuff/bits/raw/master/login > login
chmod 700 login
sed -i -e "44s/.*/USERNAME=\"$USERNAME\"/" -e "45s/.*/PASSWORD=\"$(urlencode "$PASSWORD")\"/" login
echo "/etc/bits/login created."

if [ -d "/etc/NetworkManager" ]; then DIR='/etc/NetworkManager/dispatcher.d'
elif [ -d "/etc/networkd-dispatcher" ]; then DIR='/etc/networkd-dispatcher/routable.d'
elif [ -d "/etc/network" ]; then DIR='/etc/network/if-up.d'
fi
if [ "$DIR" ] && cp login $DIR/; then
  echo -e '#!/bin/sh\n\n{ sleep 5; exec /etc/bits/login > /dev/null; } &\nexit' > $DIR/login
  chmod +x $DIR/login
  echo "Auto-login script $DIR/login created."
else
  echo "Unable to setup auto-login as the required directories were not found." >&2
fi

# $CMD $FLAGS https://github.com/sidstuff/bits/raw/master/Wifi_certificate.pfx | openssl pkcs12 -passin pass:1 -cacerts -nokeys -out ca.pem
$CMD $FLAGS https://github.com/sidstuff/bits/raw/master/ca.pem > ca.pem
echo "/etc/bits/ca.pem created."

DEV=$(ip --brief l | awk '{print $1}' | grep -m1 ^w)
PASSWORD=$(echo "$PASSWORD" | sed 's/[^a-zA-Z0-9]/\\&/g') # Prefix every non-alphanumeric character with a backslash
                                                          # so they're interpreted literally in the sed commands below
if [ -d "/etc/NetworkManager" ]; then
  echo "NetworkManager found."
  if [ -d "/run/systemd/system" ]; then
    systemctl disable --now systemd-networkd.service
    systemctl disable --now systemd-networkd.socket
    systemctl disable systemd-networkd-wait-online.service
    systemctl enable --now NetworkManager
  elif rc-status &> /dev/null; then
    rc-update del dhcpcd
    rc-service dhcpcd stop
    rc-update add NetworkManager default
    rc-service NetworkManager start
  fi
  if [ ! -d "/etc/netplan" ]; then
    $CMD $FLAGS https://github.com/sidstuff/bits/raw/master/BITS-STUDENT.nmconnection > /etc/NetworkManager/system-connections/BITS-STUDENT.nmconnection
    chmod 600 /etc/NetworkManager/system-connections/BITS-STUDENT.nmconnection
    sed -i -e "15s/.*/identity=$USERNAME/" -e "16s/.*/password=$PASSWORD/" /etc/NetworkManager/system-connections/BITS-STUDENT.nmconnection
    nmcli connection reload
    exit
  fi
fi

if [ -d "/etc/netplan" ]; then
  echo "Netplan found."
  $CMD $FLAGS https://github.com/sidstuff/bits/raw/master/99-config.yaml > /etc/netplan/99-config.yaml
  chmod 600 /etc/netplan/99-config.yaml
  sed -i -e "4s/.*/    $DEV:/" -e "12s/.*/            identity: \"$USERNAME\"/" -e "13s/.*/            password: \"$PASSWORD\"/" /etc/netplan/99-config.yaml
  if [ -d "/etc/NetworkManager" ]; then
    sed -i -e "5s/.*/      renderer: NetworkManager/" -e "15s/.*/            phase2-auth: \"mschapv2\"/" /etc/netplan/99-config.yaml
  elif [ -d "/etc/networkd-dispatcher" ]; then
    systemctl enable --now systemd-networkd.service
    systemctl enable --now systemd-networkd.socket
    systemctl disable systemd-networkd-wait-online.service
  else
    echo "Netplan found but neither NetworkManager nor systemd-networkd found. Exiting..." >&2
    exit 1
  fi
  netplan apply
  exit
fi

if [ -d "/var/lib/iwd" ]; then
  echo "iwd found."
  $CMD $FLAGS https://github.com/sidstuff/bits/raw/master/BITS-STUDENT.8021x > /var/lib/iwd/BITS-STUDENT.8021x
  chmod 600 /var/lib/iwd/BITS-STUDENT.8021x
  sed -i -e "3s/.*/EAP-PEAP-Phase2-Identity=$USERNAME/" -e "4s/.*/EAP-PEAP-Phase2-Password=$PASSWORD/" /var/lib/iwd/BITS-STUDENT.8021x
  if [ -d "/run/systemd/system" ]; then
    systemctl disable --now wpa_supplicant.service
    systemctl disable --now wpa_supplicant@$DEV.service
    systemctl enable iwd
    systemctl restart iwd
  elif rc-status &> /dev/null; then
    rc-update del wpa_supplicant
    rc-service wpa_supplicant stop
    rc-update add iwd default
    rc-service iwd restart
  fi
  exit
fi

if [ -d "/etc/wpa_supplicant" ]; then
  echo "wpa_supplicant found."
  if [ -d "/run/systemd/system" ]; then SUFFIX="-$DEV"; fi
  $CMD $FLAGS https://github.com/sidstuff/bits/raw/master/wpa_supplicant.conf >> /etc/wpa_supplicant/wpa_supplicant$SUFFIX.conf
  chmod 600 /etc/wpa_supplicant/wpa_supplicant$SUFFIX.conf
  sed -i -e "5s/.*/  identity=\"$USERNAME\"/" -e "6s/.*/  password=\"$PASSWORD\"/" /etc/wpa_supplicant/wpa_supplicant$SUFFIX.conf
  if [ -d "/run/systemd/system" ]; then
    systemctl disable --now wpa_supplicant.service
    systemctl enable --now wpa_supplicant@$DEV.service
  elif rc-status &> /dev/null; then
    rc-update add wpa_supplicant default
    rc-service wpa_supplicant restart
  fi
  exit
fi

echo "Neither wpa_supplicant nor iwd found. Exiting..." >&2
exit 1
