##############################################################
# .bashrc by Noobgam                                         #
#  original credits go to Violet Rodriguez                   #
#  see: https://github.com/iodine53/fancy-bashrc for details #
#                                                            #
#                                                            #
# THIS FILE AUTOMATICALLY UPDATES ITSELF!                    #
# EITHER DISABLE THE UPDATE PROCESS ON THE LAST LINE         #
# OR PLACE ANY CUSTOM CONFIGURATION IN .bash-config          #
#                                                            #
# Prompt:                                                    #
# [hostname] (pwd) (GITBRANCH) >>>                           #
#                              |||                           #
#                              ||red if user is root         #
#                              |red if login session is root #
#                              always the host color         #
#                                                            #
# Functions:                                                 #
# showhost() - show the [hostname] portion                   #
# hidehost() - hide the [hostname] portion                   #
# sethost(string name) - set the value inside [hostname]     #
#                                                            #
# showline() - print a separator line above the prompt       #
# hideline() - do not print separator line                   #
# sethc(int color) - sets the color of the '>' symbols       #
# aurget(string name) - fetches a package from the AUR       #
#                                                            #
# External Configuration File:                               #
# .bash-config - put custom functions, etc. here             #
#                                                            #
# Relatively Safe File Updater:                              #
# updatefile(string URL, string localFileName)               #
#                                                            #
##############################################################

UPDATEURL="https://raw.githubusercontent.com/Noobgam/init-script/master/"

# Don't check for updates more often than
# every $MINIMUM_UPDATE_THRESHOLD seconds.
MINIMUM_UPDATE_THRESHOLD="300"

# Updates a file, in a relatively safe manner.
# Should only replace the file if wget finishes successfully.
# param $1 string URL to pull file from
# param $2 string LOCALFILENAME to store file to
updatefile ()
{
    URL="${1}"
    LOCALFILENAME="${2}"
    TEMPFILE=$(mktemp /tmp/tmp.XXXXXX)
    wget --no-check-certificate -qO${TEMPFILE} ${URL} 2>/dev/null && mv ${TEMPFILE} ${LOCALFILENAME}
}

# Download the repo this file comes from.
get_config_files_repo ()
{
    git clone ${GIT_URL}
}

# Determine if a file was last modified more than $2 seconds ago.
# param $1 FILENAME to check
# param $2 MAX_DIFFERENCE_IN_SECONDS number of seconds ago, maximum
# return 0|1 success|failure
check_file_older_than_seconds ()
{
    FILENAME="${1}"
    MAX_DIFFERENCE_IN_SECONDS="${2}"

    # Make sure the file exists first
    if [ ! -e ${FILENAME} ]; then
        return 1;
    fi

    # Determine if stat is GNU or BSD
    stat --version >/dev/null 2>&1 && _USE_OLD_STAT=0 || _USE_OLD_STAT=1
    _NOW=$(date '+%s')

    # Each results in an environment variable called st_mtime containing
    # the modification timestamp
    case ${_USE_OLD_STAT} in
        0)
          st_mtime=$(stat --printf=%Y ${FILENAME})
          ;;
        1)
          eval $(stat -s ${FILENAME})
          ;;
    esac

    _DIFFERENCE=$((_NOW - st_mtime))
    if [ ${_DIFFERENCE} -gt ${MAX_DIFFERENCE_IN_SECONDS} ]; then
        return 0;
    else
        return 1;
    fi
}

# pretty print functions
notice() { echo -e "\e[0;34m:: \e[1;37m${*}\e[0m"; }

# placeholder functions (keeps bash from complaining loudly)
set_prompt () { :; }
set_prompt_command () { :; }
custom_hook() { :; }

# === BASIC SETUP ===

# Check for an interactive session
[ -z "$PS1" ] && return

# Enable huge history
export HISTFILESIZE=9999999999
export HISTSIZE=9999999999

# Ignore "ls" commands
export HISTIGNORE="ls"

# Save timestamp info for every command
export HISTTIMEFORMAT="[%Y-%m-%d - %H:%M:%S] "

# Dump the history file after every command
shopt -s histappend

# set up autocomplete for some commands
complete -cf sudo

# set a basic prompt, just in case.
PS1='[\u@\h \W]\$ '

# adding local user's bin directory to the path
PATH=~/bin:$PATH

# I like nano, comment these for system defaults
export EDITOR="nano -w"
export VISUAL="nano -w"

# make the window resize properly
shopt -s checkwinsize

# set the default dateformat
PROMPT_LINE_DATE_FORMAT="+%r"

# sane default; use .bash-config to edit this value
OATH_TOKEN_BASE32=""

# determine only once if oathtool is available
if which oathtool >/dev/null 2>&1; then
    OATHTOOL_PRESENT=1
fi

# This will always be shown in non-root user PS1, set it to null here to avoid formatting issues.
GITBRANCH=""

# set up custom configuration stuffs
CONFIGFILE="${HOME}/.bash-config"

# If config file doesn't exist, create it.
if [ ! -f ${CONFIGFILE} ]; then
    SYSTEM_TYPE=$(uname -s)
    touch ${CONFIGFILE}

    # Save stdout to fd 6
    exec 6>&1

    # Redirect script output to ${CONFIGFILE}
    exec > ${CONFIGFILE}

    echo "# ${SYSTEM_TYPE} system defaults"

    case "${SYSTEM_TYPE}" in
        "Linux")
          echo "alias ll='ls -alF --color=auto'"
          echo "alias la='ls -A --color=auto'"
          echo "alias l='ls -CF --color=auto'"
          echo "alias ps_mem='sudo ps_mem'"
          # default tmux ruins vim color schemas
          echo "alias tmux='tmux -2'"
          ;;
        "FreeBSD")
          echo "alias ls='ls -G'"
          echo "alias md5sum='md5'"
          ;;
        "Darwin")
          echo "alias md5sum='md5'"
          ;;
        *)
          ;;
    esac

    # Create the rest of the config file
    cat <<ENDOFCONFIGFILE

# This function is run at the end of the bash startup
unset custom_hook
custom_hook () { : # this colon is necessary if there's no content

}

# If Oath Token Generation is available on this system, enter the hash below.
OATH_TOKEN_ENABLED=0
#OATH_TOKEN_BASE32=""

# Set the format for the date line
#PROMPT_LINE_DATE_FORMAT="+%r"

export VISUAL=vim
export EDITOR=vim
UPDATE_BASHRC=1      # Controls the automatic update process
UPDATE_DIRCOLORS=1   # Determines whether to update .dir_colors from github
LINE_ENABLED=1       # Comment this line to disable the horizontal line above the prompt
GIT_ENABLED=0        # Determines if the current git branch is displayed in git repositories
ENDOFCONFIGFILE

    # Return stdout to fd 1
    exec 1>&6 6>&-
fi

# Source the config file
. ${CONFIGFILE}

# === FUNCTIONS, ETC ===

# highlight text in a pipeline, ex: cat file | highlight "searchstring"
highlight() {
    perl -pe "s/$1/\e[1;31;43m$&\e[0m/g"
}

# shortcut for downloading packages from the AUR, ex: aurget packagename
aurget () { export LASTAURPKG=${1}; wget https://aur.archlinux.org/cgit/aur.git/snapshot/${1}.tar.gz; }
aurunpack () { tar -xvzf ${LASTAURPKG}.tar.gz; }

# If we're on a dumb console, stop here, we don't want color and we don't want to update.
[ "${TERM}" == "linux" ] && return

_get_git_branch () {
    GITBRANCH=$(git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1) /')
}

# Execute oathtool with the hash
_generate_oath_token () {
    if [ "${OATH_TOKEN_BASE32}" == "" ] || [ "${OATHTOOL_PRESENT}" != "1" ]; then
        echo '!TOKEN'
        return
    fi
    oathtool --totp -d6 -b ${OATH_TOKEN_BASE32}
}

# basic colors for bash prompt!
loadcolors () {
    txtblk='\e[0;30m' # Black - Regular
    txtred='\e[0;31m' # Red
    txtgrn='\e[0;32m' # Green
    txtylw='\e[0;33m' # Yellow
    txtblu='\e[0;34m' # Blue
    txtpur='\e[0;35m' # Purple
    txtcyn='\e[0;36m' # Cyan
    txtwht='\e[0;37m' # White
    bldblk='\e[1;30m' # Black - Bold
    bldred='\e[1;31m' # Red
    bldgrn='\e[1;32m' # Green
    bldylw='\e[1;33m' # Yellow
    bldblu='\e[1;34m' # Blue
    bldpur='\e[1;35m' # Purple
    bldcyn='\e[1;36m' # Cyan
    bldwht='\e[1;37m' # White
    unkblk='\e[4;30m' # Black - Underline
    undred='\e[4;31m' # Red
    undgrn='\e[4;32m' # Green
    undylw='\e[4;33m' # Yellow
    undblu='\e[4;34m' # Blue
    undpur='\e[4;35m' # Purple
    undcyn='\e[4;36m' # Cyan
    undwht='\e[4;37m' # White
    bakblk='\e[40m'   # Black - Background
    bakred='\e[41m'   # Red
    bakgrn='\e[42m'   # Green
    bakylw='\e[43m'   # Yellow
    bakblu='\e[44m'   # Blue
    bakpur='\e[45m'   # Purple
    bakcyn='\e[46m'   # Cyan
    bakwht='\e[47m'   # White
    txtrst='\e[0m'    # Text Reset
}

# make the colors accessible to this script
loadcolors

# default host color (the >>> section in the prompt)
PROMPT_HOSTNAME_COLOR=${txtwht}

# be sure to have some good defaults, just in case
PROMPT_HOSTNAME="${HOSTNAME%%.*}"
PROMPT_CWD="\w"
PROMT_HOSTNAME_BOX="\[${txtwht}\][\[${txtrst}\]${PROMPT_HOSTNAME_COLOR}\[${txtwht}\]] "

# this gets its own function for ease of use later
_update_titlebar () {
    echo -ne "\033]0;${USER}@${PROMPT_HOSTNAME%%.*}:${PWD/$HOME/~}\007"
}

# prompt commands, to change how the current working directory is displayed
long_prompt_pwd () { PROMPT_CWD="\w"; set_prompt; }
short_prompt_pwd () { PROMPT_CWD="\W"; set_prompt; }

# During runtime, or in .bash-config: Show the Hostname
showhost () { PROMPT_HOSTNAME_BOX="\[${PROMPT_HOSTNAME_COLOR}\][\[${txtrst}\]${PROMPT_HOSTNAME}\[${PROMPT_HOSTNAME_COLOR}\]] "; set_prompt; }

# During runtime, or in .bash-config: Hide the Hostname
hidehost () { PROMPT_HOSTNAME_BOX=""; set_prompt; }

# During runtime, or in .bash-config: Modify the displayed Hostname
sethost () {
    if [ -z "${1}" ]; then
        PROMPT_HOSTNAME="\h"
    else
        PROMPT_HOSTNAME="${1}"
    fi
    showhost
}

# draw a line separating each command's output
_draw_line () {
    # like to use a different date format?  Edit PROMPT_LINE_DATE_FORMAT in .bash-config.
    # The line length will adjust automagically.
    LINE_END_STRING=$(date "${PROMPT_LINE_DATE_FORMAT}")
    if [ "${OATH_TOKEN_ENABLED}" == "1" ]; then
        TOKEN_VALUE=$(_generate_oath_token)
        LINE_END_STRING="${LINE_END_STRING} [${TOKEN_VALUE}]"
    fi

    LINE_END_LENGTH=${#LINE_END_STRING}
    ((WIDTH = COLUMNS - LINE_END_LENGTH - 3))

    echo -ne "${PROMPT_HOSTNAME_COLOR}"
    for (( c = 1; c <= $WIDTH; c++ )); do echo -n "-"; done
    echo -n "|"
    echo -ne " ${txtrst}${LINE_END_STRING}\n"
}

hideline () { export LINE_ENABLED=0; set_prompt_command; }
showline () { export LINE_ENABLED=1; set_prompt_command; }

hidegit () { export GIT_ENABLED=0; set_prompt_command; }
showgit () { export GIT_ENABLED=1; set_prompt_command; }

# function to set host color, accepts 256-color syntax
# ex: sethc 140
_sethc ()
{
    loadcolors
    PROMPT_HOSTNAME_COLOR="\e[38;5;${1}m"
    PROMPT_HOSTNAME_BOX="\[${PROMPT_HOSTNAME_COLOR}\][\[${txtrst}\]${PROMPT_HOSTNAME}\[${PROMPT_HOSTNAME_COLOR}\]] "
}

# Try to dynamically set the hostname color based on the hostname's md5sum
_sethc $(printf "%d\n" 0x$(echo ${HOSTNAME} | md5sum | head -c 2))

# Function to build the PROMPT_COMMAND based on enabled options
set_prompt_command ()
{
    PROMPT_COMMAND="history -a; _update_titlebar; "

    [ "${LINE_ENABLED}" == "1" ] && PROMPT_COMMAND="${PROMPT_COMMAND} _draw_line; "
    [ "${GIT_ENABLED}" == "1" ] && PROMPT_COMMAND="${PROMPT_COMMAND} _get_git_branch; "
}

# Function set the prompt.  Format:
# [hostname] (pwd) (GITBRANCH) >>>
#                              |||
#                              ||red if user is root
#                              |red if login session is root
#                              always the host color
set_prompt ()
{
    PS1="${PROMPT_HOSTNAME_BOX}\[${txtwht}\](\[${txtrst}\]${PROMPT_CWD}\[${txtwht}\]) \${GITBRANCH}\[${PROMPT_HOSTNAME_COLOR}\]>"
    # If we're root
    if [ $(id -u) == "0" ]; then
        # If we're root via sudo
        if [ -n "${SUDO_USER}" ]; then
            PS1="${PS1}>\[${bldred}\]>"
        else
            PS1="${PS1}\[${bldred}\]>>"
        fi
    else
        PS1="${PS1}>>"
    fi
    PS1="${PS1}\[${txtrst}\] "
}

# Actually set the prompt here
set_prompt

# Set the prompt command also
set_prompt_command

# During runtime, or in .bash-config: Edits the prompt color on the fly.
sethc () { _sethc ${1}; set_prompt; }

# handy function to show ALL THE COLORS
showcolors () {
    echo "=== Basic Colors ==="
    loadcolors
    for X in {0..15}; do
        BASE=$((X * 16))
        for Y in {1..16}; do
            VAL=$(((BASE + Y) - 1))
            printf '%3d' ${VAL}
            echo -ne ": \e[38;5;${VAL}m>>>${txtrst} "
        done
        echo
    done
}

# load dir_colors if it exists
[ -f ~/.dir_colors ] && [ type dircolors >/dev/null 2>&1 ] && eval $(dircolors -b ~/.dir_colors)

# binds go here
bind "\C-l":clear-screen

# run the custom configuration hook from .bash-config
custom_hook

# This function updates the .bashrc from github, if configured
updatebashrc_force ()
{
    [ "$UPDATE_BASHRC"    == 1 ] \
      && updatefile ${UPDATEURL}.bashrc ${HOME}/.bashrc
    [ "$UPDATE_DIRCOLORS" == 1 ] \
      && updatefile ${UPDATEURL}.dir_colors  ${HOME}/.dir_colors
}

updatebashrc ()
{
    [ "$UPDATE_BASHRC"    == 1 ] \
      && check_file_older_than_seconds ${HOME}/.bashrc ${MINIMUM_UPDATE_THRESHOLD} \
      && updatefile ${UPDATEURL}.bashrc ${HOME}/.bashrc
    [ "$UPDATE_DIRCOLORS" == 1 ] \
      && check_file_older_than_seconds ${HOME}/.dir_colors ${MINIMUM_UPDATE_THRESHOLD} \
      && updatefile ${UPDATEURL}.dir_colors  ${HOME}/.dir_colors
}

# Make it so, but do the update in the background
updatebashrc & disown >/dev/null 2>&1
