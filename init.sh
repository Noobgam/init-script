#!/bin/bash
set -xe
export NEEDRESTART_MODE=a

# Mostly tested for Ubuntu since I don't use other OS'es
# But doesn't contain as much OS-dependant stuff

dl_file ()
{
    URL="${1}"
    LOCALFILENAME="${2}"
    TEMPFILE=$(mktemp /tmp/tmp.XXXXXX)
    wget --no-check-certificate -qO"${TEMPFILE}" "${URL}" 2>/dev/null && mv "${TEMPFILE}" "${LOCALFILENAME}"
}

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

USER='noobgam'

ret=0
getent passwd $USER > /dev/null 2>&1 || ret=$?
if [ $ret -eq 0 ]; then
  echo "[Warn] user '$USER' already exists"
else
  adduser --disabled-password --gecos "" $USER
  echo $USER'	ALL=NOPASSWD:ALL' | tee -a '/etc/sudoers'
fi
unset ret

USER_HOME="/home/$USER"
MANDATORY_PKGS='git python3 wget vim apt-transport-https ca-certificates curl python3-pip net-tools netcat-openbsd lsof htop'
GIT_PATH='https://github.com/Noobgam/init-script.git'

# do I need this? This only happens in docker probably.
ln -snf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
echo Europe/Berlin > /etc/timezone


ONEDARK_REPO='https://raw.githubusercontent.com/joshdick/onedark.vim/master'

if ! dpkg -s $MANDATORY_PKGS >/dev/null 2>&1; then
  apt-get install $MANDATORY_PKGS -y
fi

CLONED_PATH=$(mktemp -d)

### start background git clone ###
echo "[INFO] Checking out projects"

mkdir -p "$USER_HOME/.vim/pack/default/start"
git clone 'https://github.com/sheerun/vim-polyglot' "$USER_HOME/.vim/pack/default/start/vim-polyglot" >/dev/null 2>&1 &

git clone "$GIT_PATH" "$CLONED_PATH" >/dev/null 2>&1

### INITIALIZE USER ###

mv "$CLONED_PATH/.bashrc" "$USER_HOME"
mkdir -p "$USER_HOME/.ssh"

# do not overwrite, because user could have existed already.
tee -a "$USER_HOME/.ssh/authorized_keys" < "$CLONED_PATH"/.ssh/authorized_keys >/dev/null 2>&1

echo "[INFO] Initialized user"

### VIM ###

mkdir -p "$USER_HOME/.vim/colors"
mkdir -p "$USER_HOME/.vim/autoload"

mv "$CLONED_PATH"/.vimrc "$USER_HOME"

dl_file "$ONEDARK_REPO/colors/onedark.vim" "$USER_HOME/.vim/colors/onedark.vim"
dl_file "$ONEDARK_REPO/autoload/onedark.vim" "$USER_HOME/.vim/autoload/onedark.vim"
# waits for git clone vim-polyglot
wait

echo "[INFO] Initialized VIM"

cp -r "$USER_HOME/.vim" /root/.vim
cp -r "$USER_HOME/.vimrc" /root/.vimrc
cp -r "$USER_HOME/.bashrc" /root/.bashrc

echo "[INFO] Initialized vim and bashrc for root"

### CLEANUP ###

echo "[INFO] Installing pip3 packages"

pip3 install --break-system-packages ps_mem

echo "[INFO] Running interactive startup procedure"

python3 "$CLONED_PATH"/startup.py "$CLONED_PATH"

rm -rf "$CLONED_PATH"
chown -R noobgam:noobgam "$USER_HOME"
chmod 600 "$USER_HOME/.ssh/authorized_keys"

echo "[SUCCESS] Cleanup OK"

unset -f dl_file
unset NEEDRESTART_MODE

source "$USER_HOME/.bashrc"