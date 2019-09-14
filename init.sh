#!/bin/sh

# Mostly tested for Ubuntu since I don't use other OS'es
# But doesn't contain as much OS-dependant stuff

dl_file ()
{
    URL="${1}"
    LOCALFILENAME="${2}"
    TEMPFILE=$(mktemp /tmp/tmp.XXXXXX)
    wget --no-check-certificate -qO${TEMPFILE} ${URL} 2>/dev/null && mv ${TEMPFILE} ${LOCALFILENAME}
}

set -e

sudo apt-get update

USER='noobgam'

# check if user exists. If user is present something will fail afterwards or get overriden.
# so it will fail due to 'set -e' for now.
ret=0
sudo getent passwd $USER > /dev/null 2>&1 || ret=$?
if [ $ret -eq 0 ]; then
  echo 'User already exists, conflict resolution is not implemented yet'
  return
fi
unset ret

USER_HOME='/home/'$USER
MANDATORY_PKGS='git python3 wget vim apt-transport-https ca-certificates curl'
URL_PATH='https://raw.githubusercontent.com/Noobgam/init-script/master/'
GIT_PATH='https://github.com/Noobgam/init-script.git'

if ! dpkg -s $MANDATORY_PKGS >/dev/null 2>&1; then
  sudo apt-get install $MANDATORY_PKGS -y
fi

CLONED_PATH=$(mktemp -d)

sudo git clone $GIT_PATH $CLONED_PATH

### INITIALIZE USER ###

sudo adduser --disabled-password --gecos "" $USER


sudo mv $CLONED_PATH/.bashrc $USER_HOME

### VIM ###

sudo mkdir -p $USER_HOME/.vim/colors
sudo mkdir -p $USER_HOME/.ssh
sudo mkdir -p $USER_HOME/.vim/autoload

sudo mv $CLONED_PATH/.vimrc $USER_HOME
sudo dl_file 'https://raw.githubusercontent.com/joshdick/onedark.vim/master/colors/onedark.vim' $USER_HOME/.vim/colors/onedark.vim
sudo dl_file 'https://raw.githubusercontent.com/joshdick/onedark.vim/master/autoload/onedark.vim' $USER_HOME/.vim/autoload/onedark.vim
sudo cat $CLONED_PATH/ssh_public/* >> $USER_HOME/.ssh/authorized_keys

sudo rm -rf CLONED_PATH

unset -f dl_file
