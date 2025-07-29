#!/bin/sh

if [ "$2" ] && [ "$2" != "up" ]; then exit; fi # Network state supplied as $2 by NetworkManager-dispatcher if used

LASTRUN=$(cat /etc/bits/lastrun 2> /dev/null)
NOW=$(date +%s | tee /etc/bits/lastrun)
if [ "$((NOW-LASTRUN))" -le "1" ]; then exit; fi # Debouncing as script may run once for each interface - address family pair

logfn() { echo "$(date '+[%F %T:%3N]') $1" | tee -a /etc/bits/log; }
exitf() { echo "$(tail -n 500 /etc/bits/log)" >| /etc/bits/log; exit $1; }

DEV=$(ip route show default | cut -d ' ' -f 5)
case "$DEV" in w* ) if ! iw --version > /dev/null 2>&1; then
                      logfn "iw not found. Unable to check SSID." >&2
                    elif [ "$(iw $DEV info | grep -Po 'ssid \K.*')" != "BITS-STUDENT" ]; then
                      logfn "Not connected to BITS-STUDENT. Exiting..." >&2
                      exitf
                    else
                      logfn "Connection to BITS-STUDENT confirmed."
                    fi
                    ;;
esac

if curl -V > /dev/null 2>&1; then
  CMD='curl'
  FLAGS='-sL'
  DFLAG='-d'
elif wget -V > /dev/null 2>&1; then
  CMD='wget'
  FLAGS='--no-check-certificate -qO-'
  DFLAG='--post-data'
else
  logfn "Neither curl nor wget found. Exiting..." >&2
  exitf 1
fi

next() {
  logfn "Connection will be kept alive."
  date +%s >| /etc/bits/lastauth
  { sleep 14400; exec /etc/bits/login > /dev/null; } &
  exitf 0
}

USERNAME='F20240396'
PASSWORD='XXXXXXXXXX'
URL='https://fw.bits-pilani.ac.in:8090'
AWK='BEGIN {FS = "\""; RS = ""} {print $4}'
LINK=$($CMD $FLAGS http://github.com/sidstuff/bits/raw/master/test | awk "$AWK")
case "$LINK" in
                 success ) logfn "Internet connectivity confirmed."
                           LASTAUTH=$(cat /etc/bits/lastauth 2> /dev/null)
                           if [ "$(($(date +%s)-LASTAUTH))" -ge "14400" ] || [ "$LASTAUTH" -lt "$(date -d "$(uptime -s)" +%s)" ]; then
                             $CMD $FLAGS $URL/keepalive?$(cat /etc/bits/key) > /dev/null && next
                             logfn "Connection could not be kept alive. Exiting..." >&2
                           else exitf 0
                           fi
                           ;;
  *fw.bits-pilani.ac.in* ) $CMD $FLAGS $LINK > /dev/null
                           logfn "Captive portal found. Logging in..."
                           DATA="magic=$(echo "$LINK" | sed s/^.*?//)&username=$USERNAME&password=$PASSWORD"
                           LINK=$($CMD $DFLAG "$DATA" $FLAGS $URL | awk "$AWK")
                           case "$LINK" in
                             *keepalive* ) logfn "Login successful."; echo "$LINK" | sed s/^.*?// >| /etc/bits/key; next ;;
                                      \> ) logfn "USERNAME and PASSWORD set incorrectly within /etc/bits/login. Exiting..." >&2 ;;
                                       * ) logfn "No valid response received upon login attempt. Exiting..." >&2 ;;
                           esac
                           ;;
                       * ) logfn "No internet connectivity and no captive portal found. Exiting..." >&2
                           ;;
esac
exitf 1
