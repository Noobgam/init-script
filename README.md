## init-script

```
export NEEDRESTART_MODE=a && TMPFILE=`mktemp` && apt update && apt install curl sudo -y && curl -s https://raw.githubusercontent.com/Noobgam/init-script/master/init.sh > "$TMPFILE" && sudo bash "$TMPFILE"
```

# content

This repo contains bunch of scripts that allow me to initialize my nodes the way I like them.
Requires root access to create an account named 'noobgam'

TDB ...
