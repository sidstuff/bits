## Automate the BITS Pilani Wi-Fi connection and login on Linux

### Requirements

* Bash
* iproute2 and iw
* either wpa_supplicant or iwd
* (for auto-login) any one of NetworkManager, systemd-networkd, or ifupdown
* (optional) Netplan

### Initial setup

Run any one of
```
su -c "bash <(wget -qO- https://github.com/sidstuff/bits/raw/master/wifi-setup.sh)" -
```
```
su -c "bash <(curl -fsSL https://github.com/sidstuff/bits/raw/master/wifi-setup.sh)" -
```
while connected to another network. If no root password is set but sudo is available, prefix the above command with `sudo`.

> [!NOTE]
> If you have already setup Wi-Fi and only want to automate the login, replace `wifi-setup.sh` in the above command with `login-setup.sh`.

### Login

Once the above script is done running, and you disconnect from the other network, you should be connected to the BITS-STUDENT Wi-Fi within a few seconds.

The captive portal login should happen automatically if you have NetworkManager, systemd-networkd, or ifupdown running, but if it doesn't, you can run
```
su -c "/etc/bits/login" -
```
the file for which will have been created by the earlier command. The connection will also be kept alive by periodically fetching the keepalive page in the background when needed.

You can view the latest logs by running
```
tac /etc/bits/log | less
```
