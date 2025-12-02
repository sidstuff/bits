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
sed -i -e "s/^USERNAME=.*/USERNAME=\"$USERNAME\"/" -e "s/^PASSWORD=.*/PASSWORD=\"$(urlencode "$PASSWORD")\"/" login
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
