# shellcheck shell=bash
################################################################################
# .bashrc
# Please don't copy anything below unless you understand what the code does!
# If you're looking for a licence... WTFPL plus Warranty Clause:
#
# This program is free software. It comes without any warranty, to
#     * the extent permitted by applicable law. You can redistribute it
#     * and/or modify it under the terms of the Do What The Fuck You Want
#     * To Public License, Version 2, as published by Sam Hocevar. See
#     * http://www.wtfpl.net/ for more details.
################################################################################
#
# Note: A lot of the functions below were written for portability across Solaris

# Source global definitions
# shellcheck disable=SC1091
[[ -f /etc/bashrc ]] && . /etc/bashrc

# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

# Some people use a different file for aliases
# shellcheck source=/dev/null
[[ -f "${HOME}/.bash_aliases" ]] && . "${HOME}/.bash_aliases"

# Some people use a different file for functions
# shellcheck source=/dev/null
[[ -f "${HOME}/.bash_functions" ]] && . "${HOME}/.bash_functions"

# If we have a proxy file for defining http_proxy etc, load it up
# shellcheck source=/dev/null
[[ -f "${HOME}/.proxyrc" ]] && . "${HOME}/.proxyrc"

# Set umask for new files
umask 027

################################################################################
# Open an array of potential PATH members, including Solaris bin/sbin paths
pathArray=(
  /usr/gnu/bin /usr/xpg6/bin /usr/xpg4/bin /usr/kerberos/bin /usr/kerberos/sbin \
  /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /opt/csw/bin \
  /opt/csw/sbin /opt/sfw/bin /opt/sfw/sbin /usr/sfw/bin /usr/sfw/sbin \
  /usr/games /usr/local/games /snap/bin "$HOME"/bin "$HOME"/go/bin /usr/local/go/bin
)

# Iterate through the array and build the newPath variable using found paths
newPath=
for dir in "${pathArray[@]}"; do
  [[ -d "${dir}" ]] && newPath="${newPath}:${dir}"
done

# Now assign our freshly built newPath variable, removing any leading colon
PATH="${newPath#:}"

# Finally, export the PATH
export PATH

# A portable alternative to exists/which/type
pathfind() {
  OLDIFS="${IFS}"
  IFS=:
  for prog in ${PATH}; do
    if [[ -x "${prog}/$*" ]]; then
      printf '%s\n' "${prog}/$*"
      IFS="${OLDIFS}"
      return 0
    fi
  done
  IFS="${OLDIFS}"
  return 1
}

# Functionalise 'command -v' to allow 'if exists [command]' idiom
exists() { command -v "${1}" &>/dev/null; }
alias is_command='exists'

# Check if /usr/bin/sudo and /bin/bash exist
# If not, try to find them and suggest a symlink
if [[ ! -f /usr/bin/sudo ]]; then
  if pathfind sudo &>/dev/null; then
    printf '%s\n' "/usr/bin/sudo not found.  Please run 'sudo ln -s $(pathfind sudo) /usr/bin/sudo'"
  else
    printf '%s\n' "/usr/bin/sudo not found, and I couldn't find 'sudo' in '$PATH'"
  fi
fi
if [[ ! -f /bin/bash ]]; then
  if pathfind bash &>/dev/null; then
    printf '%s\n' "/bin/bash not found.  Please run 'sudo ln -s $(pathfind bash) /bin/bash'"
  else
    printf '%s\n' "/bin/bash not found, and I couldn't find 'bash' in '$PATH'"
  fi
fi

################################################################################
# Setup our desired shell options
shopt -s checkwinsize cdspell extglob histappend
(( BASH_VERSINFO >= 4 )) && shopt -s globstar

# Some older hosts require this to be explicitly declared
enable -a history

# Set the bash history timestamp format
export HISTTIMEFORMAT="%F,%T "

# Don't put duplicate lines in the history. See bash(1) for more options
# and ignore commands that start with a space
HISTCONTROL=ignoredups:ignorespace

# Ignore the following commands
HISTIGNORE='ls:bg:fg:history*:exit'
 
# For setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=5000
HISTFILESIZE=5000

# If we're disconnected, capture whatever is in history
trap 'history -a' SIGHUP

# Disable ctrl+s (XOFF)
stty ixany
stty ixoff -ixon

################################################################################
# Programmable Completion (Tab Completion)

# Enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [[ -f /usr/share/bash-completion/bash_completion ]]; then
    # shellcheck source=/dev/null
    . /usr/share/bash-completion/bash_completion
  elif [[ -f /etc/bash_completion ]]; then
    # shellcheck source=/dev/null
    . /etc/bash_completion
  elif [[ -f /usr/local/etc/bash_completion ]]; then
    # shellcheck source=/dev/null
    . /usr/local/etc/bash_completion
  fi
fi

# 'have()' is sometimes unset by one/all of the above completion files
# Which can upset the loading of the following conf frags
# We temporarily provide a variant of it using exists()
# TO-DO: Figure out a smarter way to handle this scenario
have() {
  unset -v have 
  exists "${1}" && have=yes
  export have
}

if [[ -d /etc/bash_completion.d/ ]]; then
  for compFile in /etc/bash_completion.d/* ; do
    # shellcheck source=/dev/null
    . "${compFile}"
  done
fi

# Clean up after ourselves
unset -f have
unset have

# Fix 'cd' tab completion
complete -d cd

# SSH auto-completion based on ~/.ssh/config.
if [[ -e ~/.ssh/config ]]; then
  complete -o "default" -W "$(grep "^Host" ~/.ssh/config | grep -v "[?*]" | cut -d " " -f2- | tr ' ' '\n')" scp sftp ssh
fi

# SSH auto-completion based on ~/.ssh/known_hosts.
if [[ -e ~/.ssh/known_hosts ]]; then
  complete -o "default" -W "$(awk -F "," '{print $1}' ~/.ssh/known_hosts | sed -e 's/ .*//g' | awk '!x[$0]++')" scp sftp ssh
fi

################################################################################
# OS specific tweaks

if [[ "$(uname)" = "SunOS" ]]; then
  # Function to essentially sort out "Terminal Too Wide" issue in vi on Solaris
  vi() {
    local origWidth
    origWidth="${COLUMNS:-$(tput cols)}"
    (( origWidth > 160 )) && stty columns 160
    command vi "$*"
    stty columns "${origWidth}"
  }
  
elif [[ "$(uname)" = "Linux" ]]; then
  # Enable wide diff, handy for side-by-side i.e. diff -y or sdiff
  # Linux only, as -W/-w options aren't available in non-GNU
  alias diff='diff -W $(( $(tput cols) - 2 ))'
  alias sdiff='sdiff -w $(( $(tput cols) - 2 ))'
 
  # Correct backspace behaviour for some troublesome Linux servers that don't abide by .inputrc
  tty --quiet && stty erase '^?'
  
# I haven't used HP-UX in a while, but just to be sure
# we fix the backspace quirk for xterm
elif [[ "$(uname -s)" = "HP-UX" ]] && [[ "${TERM}" = "xterm" ]]; then
  stty intr ^c
  stty erase ^?
fi

################################################################################
# Aliases

# If .curl-format exists, AND 'curl' is available, enable curl-trace alias
# See: https://github.com/wickett/curl-trace
if [[ -f ~/.curl-format ]] && exists curl; then
  alias curl-trace='curl -w "@/${HOME}/.curl-format" -o /dev/null -s'
fi

# Again, cater for Solaris.  First test for GNU:
if ls --color=auto &>/dev/null; then
  alias ls='ls --color=auto -F'
# Try for OSX, why not?
elif [[ $(uname) = "Darwin" ]]; then
  alias ls='ls -FG'
else
  alias ls='ls -F'
fi

# Check whether 'ls' supports human readable ( -h )
if ls -h /dev/null >/dev/null 2>&1; then
  alias l.='ls -lAdFh .*'    # list only hidden things
  alias la='ls -lAFh'        # list all
  alias ll='ls -alFh'        # list long
else
  alias l.='ls -lAdF .*'    # list only hidden things
  alias la='ls -lAF'        # list all
  alias ll='ls -alF'        # list long
fi

# When EDITOR == vim ; alias vi to vim
[[ "${EDITOR##*/}" = "vim" ]] && alias vi='vim'
exists vim && alias vi='vim'

# It looks like blindly asserting the following upsets certain 
# Solaris versions of *grep.  So we throw in an extra check
if echo "test" | grep --color=auto test &>/dev/null; then
  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

################################################################################
# Colours

# Generated using https://dom111.github.io/grep-colors
GREP_COLORS='sl=49;39:cx=49;39:mt=49;31;1:fn=49;32:ln=49;33:bn=49;33:se=1;36'
#GREP_OPTIONS='--color=auto' # Deprecated

# Generated by hand, referencing http://linux-sxs.org/housekeeping/lscolors.html
LS_COLORS='di=1;32:fi=0:ln=1;33;40:pi=1;33;40:so=1;33;40:bd=1;33;40:cd=1;33;40:or=5;33:mi=0:ex=1;31:*.rpm=1;31'

export GREP_COLORS LS_COLORS

# Check for dircolors and if found, process .dircolors
# This sets up colours for 'ls' via LS_COLORS
if [[ -z "${LS_COLORS}" ]] && pathfind dircolors &>/dev/null; then
  if [[ -r ~/.dircolors ]]; then
    eval "$(dircolors -b ~/.dircolors)"
  else
    eval "$(dircolors -b)"
  fi
fi

################################################################################
# Functions

# Because you never know what crazy systems are out there
exists apropos || apropos() { man -k "$*"; }

# Function to kill the parents of interruptable zombies, will not touch pid 1
boomstick() {
  # shellcheck disable=SC2009
  for ppid in $(ps -A -ostat,ppid | grep -e '^[Zz]' | awk '{print $2}' | sort | uniq); do
    [[ -z "${ppid}" ]] && return 0
    if (( ppid == 1 )); then
      printf '%s\n' "PPID is '1', I won't kill that, Ash!"
    else
      kill -HUP "${ppid}"
    fi
  done
}

# Bytes to Human Readable conversion function from http://unix.stackexchange.com/a/98790
bytestohuman() {
  # converts a byte count to a human readable format in IEC binary notation (base-1024),
  # rounded to two decimal places for anything larger than a byte. 
  # switchable to padded format and base-1000 if desired.
  if [[ "${1}" = "-h" ]]; then
    printf '%s\n' "Usage: bytestohuman [number to convert] [pad or not yes/no] [base 1000/1024]"
    return 0
  fi
  local L_BYTES="${1:-0}"
  local L_PAD="${2:-no}"
  local L_BASE="${3:-1024}"
  awk -v bytes="${L_BYTES}" -v pad="${L_PAD}" -v base="${L_BASE}" 'function human(x, pad, base) {
   if(base!=1024)base=1000
   basesuf=(base==1024)?"iB":"B"

   s="BKMGTEPYZ"
   while (x>=base && length(s)>1)
         {x/=base; s=substr(s,2)}
   s=substr(s,1,1)

   xf=(pad=="yes") ? ((s=="B")?"%5d   ":"%8.2f") : ((s=="B")?"%d":"%.2f")
   s=(s!="B") ? (s basesuf) : ((pad=="no") ? s : ((basesuf=="iB")?(s "  "):(s " ")))

   return sprintf( (xf " %s\n"), x, s)
  }
  BEGIN{print human(bytes, pad, base)}'
  return $?
}

# Convert comma separated list to long format e.g. id user | tr "," "\n"
# See also n2c() and n2s() for the opposite behaviour
c2n() {
  while read -r; do 
    printf -- '%s\n' "${REPLY}" | tr "," "\\n"
  done < "${1:-/dev/stdin}"
}

# Capitalise words
# This is a bash-portable way to do this.
# To achieve with awk, use awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
# Known problem: leading whitespace is chomped.
capitalise() {
  # Ignore any instances of '*' that may be in a file
  local GLOBIGNORE="*"
  
  # Check that stdin or $1 isn't empty
  if [[ -t 0 ]] && [[ -z "${1}" ]]; then
    printf '%s\n' "Usage:  capitalise string" ""
    printf '\t%s\n' "Capitalises the first character of STRING and/or its elements."
    return 0
  # Disallow both piping in strings and declaring strings
  elif [[ ! -t 0 ]] && [[ ! -z "${1}" ]]; then
    printf '%s\n' "[ERROR] capitalise: Please select either piping in or declaring a string to capitalise, not both."
    return 1
  fi

  # If parameter is a file, or stdin is used, action that first
  # shellcheck disable=SC2119
  if [[ -r "${1}" ]]||[[ ! -t 0 ]]; then
    # We require an exit condition for 'read', this covers the edge case
    # where a line is read that does not have a newline
    eof=
    while [[ -z "${eof}" ]]; do
      # Read each line of input
      read -r || eof=true
      # If the line is blank, then print a blank line and continue
      if [[ -z "${REPLY}" ]]; then
        printf '%s\n' ""
        continue
      fi
      # Split each line element for processing
      for inString in ${REPLY}; do
        # If inString is an integer, skip to the next element
        is_integer "${inString}" && continue
        capitalise-string "${inString}"
      # We use to trim to remove any trailing whitespace
      done | paste -sd ' ' -
    done < "${1:-/dev/stdin}"

  # Otherwise, if a parameter exists, then capitalise all given elements
  # Processing follows the same path as before.
  elif [[ -n "$*" ]]; then
    for inString in "$@"; do
      capitalise-string "${inString}"
    done | paste -sd ' ' -
  fi
  
  # Unset GLOBIGNORE, even though we've tried to limit it to this function
  local GLOBIGNORE=
}

# Setup a function for capitalising a single string
# This is used by the above capitalise() function
# The portable version depends on toupper() and trim()
if (( BASH_VERSINFO >= 4 )); then
  capitalise-string() {
    printf -- '%s\n' "${1^}"
  }
else
  capitalise-string() {
    # Split off the first character, uppercase it and trim
    # Next, print the string from the second character onwards
    printf -- '%s\n' "$(toupper "${1:0:1}" | trim)${1:1}"
  }
fi

# Wrap 'cd' to automatically update GIT_BRANCH when necessary
cd() {
  command cd "${@}" || return 1
  if [[ "${PS1_GIT_MODE}" = True ]]; then
    if is_gitdir; then
      GIT_BRANCH="$(git branch 2>/dev/null| sed -n '/\* /s///p')"
    else
      GIT_BRANCH="NON-GIT"
    fi
    export GIT_BRANCH
  fi
}

# Print the given text in the center of the screen.
# From https://github.com/Haroenv/config/blob/master/.bash_profile
center() {
  width="${COLUMNS:-$(tput cols)}"
  if [[ -r "${1}" ]]; then
    pr -o "$(( width/2/2 ))" -t < "${1}"
  else
    str="$*";
    len=${#str};
    (( len >= width )) && echo "$str" && return;
    for ((i = 0; i < $((((width - len)) / 2)); i++)); do
      echo -n " ";
    done;
    echo "$str";
  fi
}

# Check YAML syntax
checkyaml() {
  local textGreen textRed textRst
  textGreen=$(tput setaf 2)
  textRed=$(tput setaf 1)
  textRst=$(tput sgr0)

  # Check that $1 is defined...
  if [[ -z "${1}" ]]; then
    printf '%s\n' "Usage:  checkyaml file" ""
    printf '\t%s\n'  "Check the YAML syntax in FILE"
    return 1
  fi
  
  # ...and readable
  if [[ ! -r "${1}" ]]; then
    printf '%s\n' "${textRed}[ERROR]${textRst} checkyaml: '${1}' does not appear to exist or I can't read it."
    return 1
  else
    local file
    file="${1}"
  fi

  # If we can see the internet, let's use it!
  if ! wget -T 1 http://yamllint.com/ &>/dev/null; then
    curl --data-urlencode yaml'@'"${file:-/dev/stdin}" -d utf8='%E2%9C%93' -d commit=Go  http://yamllint.com/ --trace-ascii out -G 2>&1 | grep -E 'div.*background-color'

  # Check the YAML contents, if there's no error, print out a message saying so
  elif python -c 'import yaml, sys; print yaml.load(sys.stdin)' < "${file:-/dev/stdin}" &>/dev/null; then
    printf '%s\n' "${textGreen}[OK]${textRst} checkyaml: It seems the provided YAML syntax is ok."

  # Otherwise, print out an error message and dump the trace
  else
    printf '%s\n' "${textRed}[ERROR]${textRst} checkyaml: It seems there is an issue with the provided YAML syntax." ""
    python -c 'import yaml, sys; print yaml.load(sys.stdin)' < "${file:-/dev/stdin}"
  fi
}

# Try to enable clipboard functionality
# Terse version of https://raw.githubusercontent.com/rettier/c/master/c
if is_command pbcopy; then
  clipin() { pbcopy; }
  clipout() { pbpaste; }
elif is_command xclip; then
  clipin() { xclip -selection c; }
  clipout() { xclip -selection clipboard -o; }
elif is_command xsel ; then
  clipin() { xsel --clipboard --input; }
  clipout() { xsel --clipboard --output; }
else
  clipin() { printf '%s\n' "No clipboard capability found" >&2; }
  clipout() { printf '%s\n' "No clipboard capability found" >&2; }
fi

# Indent code by four spaces, useful for posting in markdown
codecat() { indent 4 "${1}"; }

# Provide a function to compress common compressed Filetypes
compress() {
  File=$1
  shift
  case "${File}" in
    (*.tar.bz2) tar cjf "${File}" "$@"  ;;
    (*.tar.gz)  tar czf "${File}" "$@"  ;;
    (*.tgz)     tar czf "${File}" "$@"  ;;
    (*.zip)     zip "${File}" "$@"      ;;
    (*.rar)     rar "${File}" "$@"      ;;
    (*)         echo "Filetype not recognized" ;;
  esac
}

# Wrap long comma separated lists by element count (default: 8 elements)
csvwrap() {
  export splitCount="${1:-8}"
  perl -pe 's{,}{++$n % $ENV{splitCount} ? $& : ",\\\n"}ge'
  unset splitCount
}

# Optional error handling function
# See: https://www.reddit.com/r/bash/comments/5kfbi7/best_practices_error_handling/
die() {
  tput setaf 1
  printf '%s\n' "$@" >&2
  tput sgr0
  return 1
}

# Basic step-in function for dos2unix
# This simply removes dos line endings using 'sed'
if ! command -v dos2unix &>/dev/null; then
  dos2unix() {
    if [[ "${1:0:1}" = '-' ]]; then
      printf '%s\n' "This is a simple step-in function, '${1}' isn't supported"
      return 1
    fi
    if [[ -w "${1}" ]]; then
      sed -ie 's/\r//g' "${1}"
    else
      sed -e 's/\r//g' -
    fi
  }
fi

################################################################################
# NOTE: This function is a work in progress
# TO-DO: Factor in leaps
################################################################################
# Calculate how many seconds since epoch
# Portable version based on http://www.etalabs.net/sh_tricks.html
# We strip leading 0's in order to prevent unwanted octal math
# This seems terse, but the vars are the same as their 'date' formats
epoch() {
  local y j h m s yo

# POSIX portable way to assign all our vars
IFS=: read -r y j h m s <<-EOF
$(date -u +%Y:%j:%H:%M:%S)
EOF

  # yo = year offset
  yo=$(( y - 1600 ))
  y=$(( (yo * 365 + yo / 4 - yo / 100 + yo / 400 + $(( 10#$j )) - 135140) * 86400 ))

  printf -- '%s\n' "$(( y + ($(( 10#$h )) * 3600) + ($(( 10#$m )) * 60) + $(( 10#$s )) ))"
}

# Calculate how many days since epoch
epochdays() {
  printf '%s\n' "$(( $(epoch) / 86400 ))"
}

# Function to extract common compressed file types
extract() {
 if [[ -z "${1}" ]]; then
    # display usage if no parameters given
    printf '%s\n' "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|exe|tar.bz2|tar.gz|tar.xz|rpm>"
 else
    if [[ -r "${1}" ]]; then
      case "${1}" in
        (*.tar.bz2)   tar xvjf ./"${1}"    ;;
        (*.tar.gz)    tar xvzf ./"${1}"    ;;
        (*.tar.xz)    tar xvJf ./"${1}"    ;;
        (*.lzma)      unlzma ./"${1}"      ;;
        (*.bz2)       bunzip2 ./"${1}"     ;;
        (*.rar)       unrar x -ad ./"${1}" ;;
        (*.gz)        gunzip ./"${1}"      ;;
        (*.tar)       tar xvf ./"${1}"     ;;
        (*.tbz2)      tar xvjf ./"${1}"    ;;
        (*.tgz)       tar xvzf ./"${1}"    ;;
        (*.zip)       unzip ./"${1}"       ;;
        (*.Z)         uncompress ./"${1}"  ;;
        (*.7z)        7z x ./"${1}"        ;;
        (*.xz)        unxz ./"${1}"        ;;
        (*.exe)       cabextract ./"${1}"  ;;
        (*.rpm)       rpm2cpio ./"${1}" | cpio -idmv ;;
        (*)           echo "extract: '${1}' - unknown archive method" ;;
      esac
    else
      printf '%s\n' "'${1}' - file not found or not readable"
    fi
  fi
}

# Try to find out if we're authenticating locally or remotely
get_auth_type() {
  if grep "^${USER}:" /etc/passwd &>/dev/null; then
    printf -- '%s\n' "Local"
  else
    printf -- '%s\n' "Network"
  fi
}

# Try to emit a certificate expiry date from openssl
get_certexpiry() {
  local host="${1}"
  local hostport="${2:-443}"
  echo | openssl s_client -showcerts -host "${host}" -port "${hostport}" 2>&1 \
    | openssl x509 -inform pem -noout -enddate \
    | cut -d "=" -f 2
}

# Because $SHELL is an unreliable thing to test against, we provide this function
# This won't work for 'fish', which needs 'ps -p %self' or similar
# non-bourne-esque syntax.  Good thing we don't care about 'fish'
get_shell() {
  if [ -r "/proc/$$/cmdline" ]; then
    # We use 'tr' because 'cmdline' files have NUL terminated lines
    # TO-DO: Possibly handle multi-word output e.g. 'busybox ash'
    printf -- '%s\n' "$(tr '\0' ' ' </proc/"$$"/cmdline)"
  elif ps -p "$$" >/dev/null 2>&1; then
    # This double-awk caters for situations where CMD/COMMAND
    # might be a full path e.g. /usr/bin/zsh
    ps -p "$$" | tail -n 1 | awk '{print $NF}' | awk -F '/' '{print $NF}'
  # This one works well except for busybox
  elif ps -o comm= -p $$ >/dev/null 2>&1; then
    ps -o comm= -p $$
  elif ps -o pid,comm= >/dev/null 2>&1; then
    ps -o pid,comm= | awk -v ppid="$$" '$1==ppid {print $2}'
  else
    case "${BASH_VERSION}" in (*.*) printf '%s\n' "bash";; esac; return 0
    case "${KSH_VERSION}" in (*.*) printf '%s\n' "ksh";; esac; return 0
    case "${ZSH_VERSION}" in (*.*) printf '%s\n' "zsh";; esac; return 0
    # If we get to this point, fail out:
    printf '%s\n' "Unable to find method to determine the shell"
    return 1
  fi
}

# Let 'git' take the perf hit of setting GIT_BRANCH rather than PROMPT_COMMAND
# There's no one true way to get the current git branch, they all have pros/cons
# See e.g. https://stackoverflow.com/q/6245570
if is_command git; then
  git() {
    command git "${@}"
    GIT_BRANCH="$(command git branch 2>/dev/null| sed -n '/\* /s///p')"
    export GIT_BRANCH
  }
fi

# Small function to try and ensure setprompt etc behaves when escalating to root
# I don't want to override the default behaviour of 'sudo', hence the name
godmode() {
  if [[ -z "${1}" ]]; then
    # Testing for 'sudo -E' is hackish, let's just use this
    sudo bash --rcfile "${HOME}"/.bashrc
  else
    sudo "$@"
  fi
}

# Sort history by most used commands, can optionally print n lines (e.g. histrank [n])
histrank() { 
  HISTTIMEFORMAT="%y/%m/%d %T " history \
    | awk '{out=$4; for(i=5;i<=NF;i++){out=out" "$i}; print out}' \
    | sort \
    | uniq -c \
    | sort -nk1 \
    | tail -n "${1:-$(tput lines)}"
}

# Write a horizontal line of characters
hr() {
  # shellcheck disable=SC2183
  printf '%*s\n' "${1:-$COLUMNS}" | tr ' ' "${2:-#}"
}

# Function to indent text by n spaces (default: 2 spaces)
indent() {
  local identWidth
  identWidth="${1:-2}"
  identWidth=$(eval "printf '%.0s ' {1..${identWidth}}")
  sed "s/^/${identWidth}/" "${2:-/dev/stdin}"
}

# Test if a given item is a function and emit a return code
is_function() {
  [[ $(type -t "${1:-grobblegobble}") = function ]]
}

# Are we within a directory that's tracked by git?
is_gitdir() {
  if [[ -d .git ]]; then
    return 0
  else
    git rev-parse --git-dir 2>&1 | grep -Eq '^.git|/.git'
  fi
}

# Test if a given value is an integer
is_integer() {
  if test "${1}" -eq "${1}" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Test if a given value is a global var, local var (default) or array
is_set() {
  case "${1}" in
    (-a|-array)
      declare -p "${2}" 2>/dev/null | grep -- "-a ${2}=" >/dev/null 2>&1
      return "${?}"
    ;;
    (-g|-global)
      export -p | grep "declare -x ${2}=" >/dev/null 2>&1
      return "${?}"
    ;;
    (-h|--help|"")
      printf -- '%s\n' "Function to test whether NAME is declared" \
        "Usage: is_set [-a(rray)|-l(ocal var)|-g(lobal var)|-h(elp)] NAME" \
        "If no option is supplied, NAME is tested as a local var"
      return 0
    ;;
    (-l|-local)
      declare -p "${2}" 2>/dev/null | grep -- "-- ${2}=" >/dev/null 2>&1
      return "${?}"
    ;;
    (*)
      declare -p "${1}" 2>/dev/null | grep -- "-- ${1}=" >/dev/null 2>&1
      return "${?}"
    ;;
  esac
}

# A reinterpretation of 'llh' from the hpuxtools toolset (hpux.ch)
# This provides human readable 'ls' output for systems
# whose version of 'ls' does not have the '-h' option
# Requires: bytestohuman function
llh() {
  # Check if the available 'ls' supports '-h', if so, use it
  if ls -h /dev/null >/dev/null 2>&1; then
    command ls -lh "$@"
  # If it doesn't support '-h', we replicate it using
  # a reinterpretation of 'llh' from the hpuxtools toolset (hpux.ch)
  # Requires: bytestohuman function
  else
    # Print out the total line
    # shellcheck disable=SC2012
    command ls -l | head -n 1

    # Read each line of 'ls -l', excluding the total line
    # shellcheck disable=SC2010
    while read -r; do
      # Get the size of the file
      size=$(echo "${REPLY}" | awk '{print $5}')
      
      # Convert it to human readable
      newSize=$(bytestohuman "${size}" no 1024)
      
      # Grab the filename from the $9th field onwards
      # This caters for files with spaces
      fileName=$(echo "${REPLY}" | awk '{print substr($0, index($0,$9))}')
      
      # Echo the line into awk, format it nicely and insert our substitutions
      echo "${REPLY}" | awk -v size="${newSize}" -v file="${fileName}" '{printf "%-11s %+2s %-10s %-10s %+11s %s %02d %-5s %s\n",$1,$2,$3,$4,size,$6,$7,$8,file}'
    done < <(command ls -l | grep -v "total")
  fi
}

# A function to log messages to the system log
# http://hacking.elboulangero.com/2015/12/06/bash-logging.html may be useful
logmsg() {
  local logIdent
  while getopts ":t:" optFlags; do
    case "${optFlags}" in
      (t)   logIdent="-t ${OPTARG}";;
      (\?)  echo "ERROR: Invalid option: '-$OPTARG'." >&2
            return 1;;
      (:)   echo \
              "Option '-$OPTARG' requires an argument. e.g. '-$OPTARG 10'" >&2
            return 1;;
    esac
  done
  shift "$((OPTIND-1))"
  if command -v systemd-cat &>/dev/null; then
    systemd-cat "${logIdent}" <<< "${*}"
  elif command -v logger &>/dev/null; then
    logger "${logIdent}" "${*}"
  else
    if [[ -w /var/log/messages ]]; then
      logFile=/var/log/messages
    elif [[ -w /var/log/syslog ]]; then
      logFile=/var/log/syslog
    else
      logFile=/var/log/logmsg
    fi
    printf '%s\n' \
      "$(date '+%b %d %T') ${HOSTNAME} ${logIdent/-t /} ${*}" >> "${logFile}" 2>&1
  fi
}

################################################################################
# NOTE: This function is a work in progress
################################################################################
# If 'mapfile' is not available, offer it as a step-in function
# Written as an attempt at http://wiki.bash-hackers.org/commands/builtin/mapfile?s[]=mapfile#to_do
#   "Create an implementation as a shell function that's portable between Ksh, Zsh, and Bash 
#    (and possibly other bourne-like shells with array support)."

# Potentially useful resources: 
# http://cfajohnson.com/shell/arrays/
# https://stackoverflow.com/a/32931403

# Known issue: No traps!  This means IFS might be left altered if 
# the function is cancelled or fails in some way

if ! exists mapfile; then
  # This is simply the appropriate section of 'help mapfile', edited, as a function:
  mapfilehelp() {
    # Hey, this exercise is for an array-capable shell, so let's use an array for this!
    # This gets around the mess of heredocs and tabbed indentation

    # shellcheck disable=SC2054,SC2102
    local mapfileHelpArray=(
    "mapfile [-n count] [-s count] [-t] [-u fd] [array]"
    "readarray [-n count] [-s count] [-t] [-u fd] [array]"
    ""
    "      Read  lines  from the standard input into the indexed array variable ARRAY, or"
    "      from file descriptor FD if the -u option is supplied.  The variable MAPFILE"
    "      is the default ARRAY."
    ""
    "      Options:"
    "        -n     Copy at most count lines.  If count is 0, all lines are copied."
    "        -s     Discard the first count lines read."
    "        -t     Nothing.  This option is here only for drop-in compatibility"
    "               'mapfile' behaviour without '-t' cannot be replicated, '-t' is almost"
    "               always used, so we provide this dummy option for convenience"
    "        -u     Read lines from file descriptor FD instead of the standard input."
    ""
    "      If not supplied with an explicit origin, mapfile will clear array before assigning to it."
    ""
    "      mapfile returns successfully unless an invalid option or option argument is supplied," 
    "      ARRAY is invalid or unassignable, or if ARRAY is not an indexed array."
    )
    printf '%s\n' "${mapfileHelpArray[@]}"
  }

  mapfile() {
    local elementCount elementDiscard fileDescr IFS
    unset MAPFILE
    # Handle our various options
    while getopts ":hn:s:tu:" flags; do
      case "${flags}" in
        (h) mapfile-help; return 0;;
        (n) elementCount="${OPTARG}";;
        (s) elementDiscard="${OPTARG}";;
        (t) :;; #Only here for compatibility
        (u) fileDescr="${OPTARG}";;
        (*) mapfile-help; return 1;;
      esac
    done
    shift "$(( OPTIND - 1 ))"

    IFS=$'\n'     # Temporarily set IFS to newlines
    set -f        # Turn off globbing
    set +H        # Prevent parsing of '!' via history substitution

    # If a linecount is set, we build the array element by element
    if [[ -n "${elementCount}" ]] && (( elementCount > 0 )); then
      # First, if we're discarding elements:
      for ((i=0;i<elementDiscard;i++)); do
        read -r
        echo "${REPLY}" >/dev/null 2>&1
      done
      # Next, read the input stream into MAPFILE
      i=0
      eof=
      while (( i < elementCount )) && [[ -z "${eof}" ]]; do
        read -r || eof=true
        MAPFILE+=( "${REPLY}" )
        (( i++ ))
      done
    # Otherwise we just read the whole lot in
    else
      while IFS= read -r; do
        MAPFILE+=( "${REPLY}" )
      done
      [[ "${REPLY}" ]] && MAPFILE+=( "${REPLY}" )

      # If elementDiscard is declared, then we can quickly reindex like so:
      if [[ -n "${elementDiscard}" ]]; then
        MAPFILE=( "${MAPFILE[@]:$elementDiscard}" )
      fi
    fi <&"${fileDescr:-0}"

    # Finally, rename the array if required
    # I would love to know a better way to handle this
    if [[ -n "${1}" ]]; then
      # shellcheck disable=SC2034
      for element in "${MAPFILE[@]}"; do
        eval "$1+=( \"\${element}\" )"
      done
    fi

    # Set f and H back to normal
    set +f
    set -H
  }
  # And finally alias 'readarray'
  alias readarray='mapfile'
fi

# Function to list the members of a group.  
# Replicates the absolute basic functionality of a real 'members' command
if ! exists members; then
  members() {
    [[ "$(getent group "${1?No Group Supplied}" | cut -d ":" -f4-)" ]] \
      && getent group "${1}" | cut -d ":" -f4-
  }
fi

# Convert multiple lines to comma separated format
# See also c2n() for the opposite behaviour
n2c() { paste -sd ',' "${1:--}"; }

# Convert multiple lines to space separated format
n2s() { paste -sd ' ' "${1:--}"; }

# Backup a file with the extension '.old'
old() { cp --reflink=auto "${1}"{,.old} 2>/dev/null || cp "${1}"{,.old}; }

# A function to print a specific line from a file
# TO-DO: Update it to handle globs e.g. 'printline 4 *'
printline() {
  # If $1 is empty, print a usage message
  if [[ -z "${1}" ]]; then
    printf '%s\n' "Usage:  printline n [file]" ""
    printf '\t%s\n' "Print the Nth line of FILE." "" \
      "With no FILE or when FILE is -, read standard input instead."
    return 0
  fi

  # Check that $1 is a number, if it isn't print an error message
  # If it is, blindly convert it to base10 to remove any leading zeroes
  case $1 in
    (''|*[!0-9]*) printf '%s\n' "[ERROR] printline: '${1}' does not appear to be a number." "" \
                    "Run 'printline' with no arguments for usage.";
                  return 1 ;;
    (*)           local lineNo="$((10#$1))" ;;
  esac

  # Next, if $2 is set, check that we can actually read it
  if [[ -n "${2}" ]]; then
    if [[ ! -r "${2}" ]]; then
      printf '%s\n' "[ERROR] printline: '$2' does not appear to exist or I can't read it." "" \
        "Run 'printline' with no arguments for usage."
      return 1
    else
      local file="${2}"
    fi
  fi

  # Finally after all that testing is done, we throw in a cursory test for 'sed'
  if is_command sed; then
    sed -ne "${lineNo}{p;q;}" -e "\$s/.*/[ERROR] printline: End of stream reached./" -e '$ w /dev/stderr' "${file:-/dev/stdin}"
  # Otherwise we print a message that 'sed' isn't available
  else
    printf '%s\n' "[ERROR] printline: This function depends on 'sed' which was not found."
    return 1
  fi
}

# Start an HTTP server, optionally specifying the port and directory
# Derived from (among others)
# * https://gist.github.com/alxklo/8408169
# * https://github.com/2001db8/simpleHTTPSserver.sh
# * https://stackoverflow.com/a/46595749
# See also: https://gist.github.com/willurd/5720255
# shellcheck disable=SC2140
quickserve() {
  if [[ "${1}" = "-h" ]]; then
    printf '%s\n' "Usage: quickserve [port(default: 8000)] [path(default: cwd)]"
    return 0
  fi
  local port="${1:-8000}"
  httpModule=$( \
    python -c 'import sys; \
    print("http.server" if sys.version_info[:2] > (2,7) else "SimpleHTTPServer")'
  ) 
  trap 'kill -9 "${httpPid}"' SIGHUP SIGINT SIGTERM
  (
    cd "${2:-.}" || return 1
    case "${httpModule}" in
      (SimpleHTTPServer)
        python -c "import sys,BaseHTTPServer,SimpleHTTPServer; \
          sys.tracebacklimit=0; \
          httpd = BaseHTTPServer.HTTPServer(('', ${port}), SimpleHTTPServer.SimpleHTTPRequestHandler); \
          httpd.serve_forever()"
        httpPid="$!"
      ;;
      (http.server)
        python -c "import sys,http.server,http.server,ssl,signal; \
          signal.signal(signal.SIGINT, lambda x,y: sys.exit(0)); \
          httpd = http.server.HTTPServer(('', ${port}), http.server.SimpleHTTPRequestHandler) ; \
          httpd.serve_forever()"
        httpPid="$!"
      ;;
      (*)
        printf -- '%s\n' "No suitable python module could be found"
        return 1
      ;;
    esac
  )
}

# This function prints the terminfo details for 'xterm-256color'
# This is for importing this into systems that don't have this
print-xterm-256color() {
cat <<'NEWTERM'
xterm-256color|xterm with 256 colors,
        am, bce, ccc, km, mc5i, mir, msgr, npc, xenl,
        colors#256, cols#80, it#8, lines#24, pairs#32767,
        acsc=``aaffggiijjkkllmmnnooppqqrrssttuuvvwwxxyyzz{{||}}~~,
        bel=^G, blink=\E[5m, bold=\E[1m, cbt=\E[Z, civis=\E[?25l,
        clear=\E[H\E[2J, cnorm=\E[?12l\E[?25h, cr=^M,
        csr=\E[%i%p1%d;%p2%dr, cub=\E[%p1%dD, cub1=^H,
        cud=\E[%p1%dB, cud1=^J, cuf=\E[%p1%dC, cuf1=\E[C,
        cup=\E[%i%p1%d;%p2%dH, cuu=\E[%p1%dA, cuu1=\E[A,
        cvvis=\E[?12;25h, dch=\E[%p1%dP, dch1=\E[P, dl=\E[%p1%dM,
        dl1=\E[M, ech=\E[%p1%dX, ed=\E[J, el=\E[K, el1=\E[1K,
        flash=\E[?5h$<100/>\E[?5l, home=\E[H, hpa=\E[%i%p1%dG,
        ht=^I, hts=\EH, ich=\E[%p1%d@, il=\E[%p1%dL, il1=\E[L,
        ind=^J, indn=\E[%p1%dS,
        initc=\E]4;%p1%d;rgb\:%p2%{255}%*%{1000}%/%2.2X/%p3%{255}%*%{1000}%/%2.2X/%p4%{255}%*%{1000}%/%2.2X\E\\,
        invis=\E[8m, is2=\E[!p\E[?3;4l\E[4l\E>, kDC=\E[3;2~,
        kEND=\E[1;2F, kHOM=\E[1;2H, kIC=\E[2;2~, kLFT=\E[1;2D,
        kNXT=\E[6;2~, kPRV=\E[5;2~, kRIT=\E[1;2C, kb2=\EOE,
        kbs=\177, kcbt=\E[Z, kcub1=\EOD, kcud1=\EOB, kcuf1=\EOC,
        kcuu1=\EOA, kdch1=\E[3~, kend=\EOF, kent=\EOM, kf1=\EOP,
        kf10=\E[21~, kf11=\E[23~, kf12=\E[24~, kf13=\E[1;2P,
        kf14=\E[1;2Q, kf15=\E[1;2R, kf16=\E[1;2S, kf17=\E[15;2~,
        kf18=\E[17;2~, kf19=\E[18;2~, kf2=\EOQ, kf20=\E[19;2~,
        kf21=\E[20;2~, kf22=\E[21;2~, kf23=\E[23;2~,
        kf24=\E[24;2~, kf25=\E[1;5P, kf26=\E[1;5Q, kf27=\E[1;5R,
        kf28=\E[1;5S, kf29=\E[15;5~, kf3=\EOR, kf30=\E[17;5~,
        kf31=\E[18;5~, kf32=\E[19;5~, kf33=\E[20;5~,
        kf34=\E[21;5~, kf35=\E[23;5~, kf36=\E[24;5~,
        kf37=\E[1;6P, kf38=\E[1;6Q, kf39=\E[1;6R, kf4=\EOS,
        kf40=\E[1;6S, kf41=\E[15;6~, kf42=\E[17;6~,
        kf43=\E[18;6~, kf44=\E[19;6~, kf45=\E[20;6~,
        kf46=\E[21;6~, kf47=\E[23;6~, kf48=\E[24;6~,
        kf49=\E[1;3P, kf5=\E[15~, kf50=\E[1;3Q, kf51=\E[1;3R,
        kf52=\E[1;3S, kf53=\E[15;3~, kf54=\E[17;3~,
        kf55=\E[18;3~, kf56=\E[19;3~, kf57=\E[20;3~,
        kf58=\E[21;3~, kf59=\E[23;3~, kf6=\E[17~, kf60=\E[24;3~,
        kf61=\E[1;4P, kf62=\E[1;4Q, kf63=\E[1;4R, kf7=\E[18~,
        kf8=\E[19~, kf9=\E[20~, khome=\EOH, kich1=\E[2~,
        kind=\E[1;2B, kmous=\E[M, knp=\E[6~, kpp=\E[5~,
        kri=\E[1;2A, mc0=\E[i, mc4=\E[4i, mc5=\E[5i, meml=\El,
        memu=\Em, op=\E[39;49m, rc=\E8, rev=\E[7m, ri=\EM,
        rin=\E[%p1%dT, rmacs=\E(B, rmam=\E[?7l, rmcup=\E[?1049l,
        rmir=\E[4l, rmkx=\E[?1l\E>, rmm=\E[?1034l, rmso=\E[27m,
        rmul=\E[24m, rs1=\Ec, rs2=\E[!p\E[?3;4l\E[4l\E>, sc=\E7,
        setab=\E[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48;5;%p1%d%;m,
        setaf=\E[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38;5;%p1%d%;m,
        sgr=%?%p9%t\E(0%e\E(B%;\E[0%?%p6%t;1%;%?%p2%t;4%;%?%p1%p3%|%t;7%;%?%p4%t;5%;%?%p7%t;8%;m,
        sgr0=\E(B\E[m, smacs=\E(0, smam=\E[?7h, smcup=\E[?1049h,
        smir=\E[4h, smkx=\E[?1h\E=, smm=\E[?1034h, smso=\E[7m,
        smul=\E[4m, tbc=\E[3g, u6=\E[%i%d;%dR, u7=\E[6n,
        u8=\E[?1;2c, u9=\E[c, vpa=\E[%i%p1%dd,
NEWTERM
}

# A small function to test connectivity to a remote host's port.
# Usage: probe-port [remote host] [port (default: 22)] [tcp/udp (default: tcp)]
probe-port() {
  timeout 1 bash -c "</dev/${3:-tcp}/${1:?No target}/${2:-22}" 2>/dev/null
}

# Use probe-port to test a remote host's ssh connectivity
probe-ssh() {
  probe-port "${1:?No target}" "${2:-22}"
}

# Alternative to 'pgrep'.  Converts the first character of the search term to [x]
# e.g. psgrep jboss = ps auxf | grep [j]boss
# This removes the need for an extra 'grep' invocation
# e.g. ps auxf | grep jboss | grep -v grep
# shellcheck disable=SC2009
psgrep() {
  [[ "${1:?Usage: psgrep [search term]}" ]]
  ps auxf | grep -i "[${1:0:1}]${1:1}" | awk '{print $2}'
}

# Get a number of random integers using $RANDOM with debiased modulo
randInt() {
  local nCount nMin nMax nMod randThres i xInt
  nCount="${1:-1}"
  nMin="${2:-1}"
  nMax="${3:-32767}"
  nMod=$(( nMax - nMin + 1 ))
  if (( nMod == 0 )); then return 3; fi
  # De-bias the modulo as best as possible
  randThres=$(( -(32768 - nMod) % nMod ))
  if (( randThres < 0 )); then
    (( randThres = randThres * -1 ))
  fi
  i=0
  while (( i < nCount )); do
    xInt="${RANDOM}"
    if (( xInt > ${randThres:-0} )); then
      printf -- '%d\n' "$(( xInt % nMod + nMin ))"
      (( i++ ))
    fi
  done
}

# 'redo' the last command, replacing all instances of 'foo' with 'bar'
# Usage: redo foo bar
redo() {
  fc -s "${1:?Search parameter missing}"="${2:?Replacement parameter missing}"
}

# Check if 'rev' is available, if not, enable a stop-gap function
if ! exists rev; then
  rev() {
    # Check that stdin or $1 isn't empty
    if [[ -t 0 ]] && [[ -z "${1}" ]]; then
      printf '%s\n' "Usage:  rev string|file" ""
      printf '\t%s\n'  "Reverse the order of characters in STRING or FILE." "" \
        "With no STRING or FILE, read standard input instead." "" \
        "Note: This is a bash function to provide the basic functionality of the command 'rev'"
      return 0
    # Disallow both piping in strings and declaring strings
    elif [[ ! -t 0 ]] && [[ -n "${1}" ]]; then
      printf '%s\n' "[ERROR] rev: Please select either piping in or declaring a string to reverse, not both."
      return 1
    fi

    # If parameter is a file, or stdin in used, action that first
    if [[ -f "${1}" ]]||[[ ! -t 0 ]]; then
      while read -r; do
        len=${#REPLY}
        rev=
        for((i=len-1;i>=0;i--)); do
          rev="$rev${REPLY:$i:1}"
        done
        printf '%s\n' "${rev}"
      done < "${1:-/dev/stdin}"
    # Else, if parameter exists, action that
    elif [[ -n "$*" ]]; then
      Line=$*
      rev=
      len=${#Line}
      for((i=len-1;i>=0;i--)); do 
        rev="$rev${Line:$i:1}"
      done
      printf '%s\n' "${rev}"
    fi
  }
fi

# A function to repeat an action any number of times
repeat() {
  # check that $1 is a digit, if not error out, if so, set the repeatNum variable
  case "${1}" in
    (*[!0-9]*|'') printf '%s\n' "[ERROR]: '${1}' is not a number.  Usage: 'repeat n command'"; return 1;;
    (*)           local repeatNum=$1;;
  esac
  # shift so that the rest of the line is the command to execute
  shift

  # Run the command in a while loop repeatNum times
  for (( i=0; i<repeatNum; i++ )); do
    "$@"
  done
}

# Create the file structure for an Ansible role
rolesetup() {
  if [[ -z "${1}" ]]; then
    printf '%s\n' "rolesetup - setup the file structure for an Ansible role." \
      "By default this creates into the current directory" \
      "and you can recursively copy the structure from there." "" \
      "Usage: rolesetup rolename" ""
    return 1
  fi

  if [[ ! -w . ]]; then
    printf '%s\n' "Unable to write to the current directory"
    return 1
  elif [[ -d "${1}" ]]; then
    printf '%s\n' "The directory '${1}' seems to already exist!"
    return 1
  else
    mkdir -p "${1}"/{defaults,files,handlers,meta,templates,tasks,vars}
    (
      cd "${1}" || return 1
      for dir in defaults files handlers meta templates tasks vars; do
        printf '%s\n' "---" > "${dir}/main.yml"
      done
    )
  fi
}

# Function for rounding floats
# Usage: round [precision] [float]
round() {
  printf "%.${2:-0}f" "${1:?No float given}"
}

# Escape special characters in a string, named for a similar function in R
sanitize() { printf -- '%q\n' "${1}"; }
alias sanitise='sanitize'

# Check if 'seq' is available, if not, provide a basic replacement function
if ! exists seq; then
  seq() {
    local first
    # If no parameters are given, print out usage
    if [[ -z "$*" ]]; then
      printf '%s\n' "Usage:"
      printf '\t%s\n'  "seq LAST" \
        "seq FIRST LAST" \
        "seq FIRST INCR LAST" \
        "Note: this is a step-in function, no args are supported."
      return 0
    fi
    
    # If only one number is given, we assume 1..n
    if [[ -z "${2}" ]]; then
      eval "printf -- '%d\\n' {1..$1}"
    # Otherwise, we act accordingly depending on how many parameters we get
    # This runs with a default increment of 1/-1 for two parameters
    elif [[ -z "${3}" ]]; then
      eval "printf -- '%d\\n' {$1..$2}"
    # and with three parameters we use the second as our increment
    elif [[ -n "${3}" ]]; then
      # First we test if the bash version is 4, if so, use native increment
      if (( BASH_VERSINFO >= 4 )); then
        eval "printf -- '%d\\n' {$1..$3..$2}"
      # Otherwise, use the manual approach
      else
        first="${1}"
        # Simply iterate through in ascending order
        if (( first < $3 )); then
          while (( first <= $3 )); do
            printf -- '%d\n' "${first}"
            first=$(( first + $2 ))
          done
        # or... undocumented feature: descending order!
        elif (( first > $3 )); then
          while (( first >= $3 )); do
            printf -- '%d\n' "${first}"
            first=$(( first - $2 ))
          done
        fi
      fi
    fi
  }
fi

# Standardise the terminal window title header
# reference: http://www.faqs.org/docs/Linux-mini/Xterm-Title.html#s3
settitle() {
  case $(tty) in
    (/dev/console|*tty*)
      : # Physical terminal, so no-op.
    ;;
    (*pts*)
      # shellcheck disable=SC2059,SC1117
      printf "\033]0;${HOSTNAME%%.*}:${PWD}\007"
      # This might also need to be expressed as
      #printf "\\033]2;${HOSTNAME}:${PWD}\\007\\003"
      # I possibly need to test and figure out a way to auto-switch between these two
    ;;
  esac
}

# shift_array <arr_name> [<n>]
# From https://www.reddit.com/r/bash/comments/aj0xm0/quicktip_shifting_arrays/
shift_array() {
  # Create nameref to real array
  local -n arr="$1"
  local n="${2:-1}"
  arr=("${arr[@]:${n}}")
}

################################################################################
# NOTE: This function is a work in progress
################################################################################
# Check if 'shuf' is available, if not, provide basic shuffle functionality
# Check commit history for a range of alternative methods - ruby, perl, python etc
# Requires: randInt function
if ! exists shuf; then
  shuf() {
    local OPTIND inputRange inputStrings nMin nMax nCount shufArray shufRepeat

    # First test that $RANDOM is available
    if (( ${RANDOM}${RANDOM} == ${RANDOM}${RANDOM} )); then
      printf -- '%s\n' "shuf: RANDOM global variable required but doesn't appear to be available"
      return 1
    fi

    while getopts ":e:i:hn:rv:" optFlags; do
      case "${optFlags}" in
        (e) inputStrings=true
            shufArray=( "${OPTARG}" )
            until [[ $(eval "echo \${$OPTIND:0:1}") = "-" ]] || [[ -z $(eval "echo \${$OPTIND}") ]]; do
              # shellcheck disable=SC2207
              shufArray+=($(eval "echo \${$OPTIND}"))
              OPTIND=$((OPTIND + 1))
            done;;
        (h)  printf '%s\n' "" "shuf - generate random permutations" \
                "" "Options:" \
                "  -e, echo.                Treat each ARG as an input line" \
                "  -h, help.                Print a summary of the options" \
                "  -i, input-range LO-HI.   Treat each number LO through HI as an input line" \
                "  -n, count.               Output at most n lines" \
                "  -o, output FILE          This option is unsupported in this version, use '> FILE'" \
                "  -r, repeat               Output lines can be repeated" \
                "  -v, version.             Print the version information" ""
              return 0;;
        (i) inputRange=true
            nMin="${OPTARG%-*}"
            nMax="${OPTARG##*-}"
            ;;
        (n) nCount="${OPTARG}";;
        (r) shufRepeat=true;;
        (v)  printf '%s\n' "shuf.  This is a bashrc function knockoff that steps in if the real 'shuf' is not found."
             return 0;;
        (\?)  printf '%s\n' "shuf: invalid option -- '-$OPTARG'." \
                "Try -h for usage or -v for version info." >&2
              returnt 1;;
        (:)  printf '%s\n' "shuf: option '-$OPTARG' requires an argument, e.g. '-$OPTARG 5'." >&2
             return 1;;
      esac
    done
    shift "$(( OPTIND - 1 ))"

    # Handle -e and -i options.  They shouldn't be together because we can't
    # understand their love.  -e is handled later on in the script
    if [[ "${inputRange}" = "true" ]] && [[ "${inputStrings}" == "true" ]]; then
      printf '%s\n' "shuf: cannot combine -e and -i options" >&2
      return 1
    fi

    # Default the reservoir size
    # This number was unscientifically chosen using "feels right" technology
    reservoirSize=4096

    # If we're dealing with a file, feed that into file descriptor 6
    if [[ -r "${1}" ]]; then
      # Size it up first and adjust nCount if necessary
      if [[ -n "${nCount}" ]] && (( $(wc -l < "${1}") < nCount )); then
        nCount=$(wc -l < "${1}")
      fi
      exec 6< "${1}"
    # Cater for the -i option
    elif [[ "${inputRange}" = "true" ]]; then
      # If an input range is provided and repeats are ok, then simply call randInt:
      if [[ "${shufRepeat}" = "true" ]] && (( nMax <= 32767 )); then
        randInt "${nCount:-$nMax}" "${nMin}" "${nMax}"
        return "$?"
      # Otherwise, print a complete range to fd6 for later processing
      else
        exec 6< <(eval "printf -- '%d\\n' {$nMin..$nMax}")
      fi
    # If we're dealing with -e, we already have shufArray
    elif [[ "${inputStrings}" = "true" ]]; then
      # First, adjust nCount as appropriate
      if [[ -z "${nCount}" ]] || (( nCount > "${#shufArray[@]}" )); then
        nCount="${#shufArray[@]}"
      fi
      # If repeats are ok, just get it over and done with
      if [[ "${shufRepeat}" = "true" ]] && (( nCount <= 32767 )); then
        for i in $(randInt "${nCount}" 1 "${#shufArray[@]}"); do
          (( i-- ))
          printf -- '%s\n' "${shufArray[i]}"
        done
        return "$?"
      # Otherwise, dump shufArray into fd6
      else
        exec 6< <(printf -- '%s\n' "${shufArray[@]}")
      fi
    # If none of the above things are in use, then we assume stdin
    else
      exec 6<&0
    fi

    # If we reach this point, then we need to setup our output filtering
    # We use this over a conventional loop, because loops are very slow
    # So, if nCount is defined, we pipe all output to 'head -n'
    # Otherwise, we simply stream via `cat` as an overglorified no-op
    if [[ -n "${nCount}" ]]; then
      headOut() { head -n "${nCount}"; }
    else
      headOut() { cat -; }
    fi

    # Start capturing everything for headOut()
    {
      # Turn off globbing for safety
      set -f
      
      # Suck up as much input as required or possible into the reservoir
      mapfile -u 6 -n "${nCount:-$reservoirSize}" -t shufArray

      # If there's more input, we start selecting random points in
      # the reservoir to evict and replace with incoming data
      i="${#shufArray[@]}"
      while IFS=$'\n' read -r -u 6; do
        n=$(randInt 1 1 "$i")
        (( n-- ))
        if (( n < ${#shufArray[@]} )); then
          printf -- '%s\n' "${shufArray[n]}"
          shufArray[n]="${REPLY}"
        else
          printf -- '%s\n' "${REPLY}"
        fi
        (( i++ ))
      done

      # At this point we very likely have something left in the reservoir
      # so we shuffle it out.  This is effectively Satollo's algorithm
      while (( ${#shufArray[@]} > 0 )); do
        n=$(randInt 1 1 "${#shufArray[@]}")
        (( n-- ))
        if (( n < ${#shufArray[@]} )) && [[ -n "${shufArray[n]}" ]]; then
          printf -- '%s\n' "${shufArray[n]}"
          unset -- 'shufArray[n]'
          # shellcheck disable=SC2206
          shufArray=( "${shufArray[@]}" )
        fi
      done
      set +f
    } | headOut
    exec 0<&6 6<&-
  }
fi

# Silence ssh motd's etc using "-q"
# Adding "-o StrictHostKeyChecking=no" prevents key prompts
# and automatically adds them to ~/.ssh/known_hosts
ssh() {
  case "${1}" in
    (-h)
      command ssh -h 2>&1 | grep -v "^unknown"
      printf '%s\n' "Overlay options:"
      printf '\t   %s\n' "nokeys: Forces password based authentication" \
        "raw: Runs ssh in its default, noisy state"
      return 0
    ;;
    (nokeys)
      command ssh \
        -o PubkeyAuthentication=no \
        -o StrictHostKeyChecking=no \
        -q \
        "${@:2}"
    ;;
    (raw)
      command ssh "${@:2}"
    ;;
    (*)
      command ssh -o StrictHostKeyChecking=no -q "${@}"
    ;;
  esac
}

# Display the fingerprint for a host
ssh-fingerprint() {
  if [[ -z "${1}" ]]; then
    printf '%s\n' "Usage: ssh-fingerprint [hostname]"
    return 1
  fi

  fingerprint=$(mktemp)

  # Test if the local host supports ed25519
  # Older versions of ssh don't have '-Q' so also likely won't have ed25519
  # If you wanted a more portable test: 'man ssh | grep ed25519' might be it
  if ssh -Q key 2>/dev/null | grep -q ed25519; then
    ssh-keyscan -t ed25519,rsa,ecdsa "${1}" > "${fingerprint}" 2> /dev/null
  else
    ssh-keyscan "${1}" > "${fingerprint}" 2> /dev/null
  fi
  ssh-keygen -l -f "${fingerprint}"
  rm -f "${fingerprint}"
}

# Test if a string contains a substring
# Example: string-contains needle haystack
string-contains() { 
  case "${2?No string given}" in 
    (*${1?No substring given}*)  return 0 ;; 
    (*)                          return 1 ;; 
  esac
}

# Provide a very simple 'tac' step-in function
if ! exists tac; then
  tac() {
    if is_command perl; then
      perl -e 'print reverse<>' < "${1:-/dev/stdin}"
    elif is_command awk; then
      awk '{line[NR]=$0} END {for (i=NR; i>=1; i--) print line[i]}' < "${1:-/dev/stdin}"
    elif is_command sed; then
      sed -e '1!G;h;$!d' < "${1:-/dev/stdin}"
    fi
  }
fi

# Throttle stdout
throttle() {
  # Check that stdin isn't empty
  if [[ -t 0 ]]; then
    printf '%s\n' "Usage:  pipe | to | throttle [n]" ""
    printf '\t%s\n'  "Increment line by line through the output of other commands" "" \
      "Delay between each increment can be defined.  Default is 1 second."
    return 0
  fi

  # Default the sleep time to 1 second
  sleepTime="${1:-1}"

  # Now we output line by line with a sleep in the middle
  while read -r; do
    printf -- '%s\n' "${REPLY}"
    sleep "${sleepTime}" 2>/dev/null || sleep 1
  done
}

# Check if 'timeout' is available, if not, enable a stop-gap function
if ! exists timeout; then
  timeout() {
    local duration

    # $# should be at least 1, if not, print a usage message
    if (( $# == 0 )); then
      printf '%s\n' "Usage:  timeout DURATION COMMAND" ""
      printf '\t%s\n' \
        "Start COMMAND, and kill it if still running after DURATION." "" \
        "DURATION is an integer with an optional suffix:" \
        "  's'  for seconds (the default)" \
        "  'm' for minutes" \
        "  'h' for hours" \
        "  'd' for days" "" \
        "Note: This is a bash function that mimics the command 'timeout'"
      return 0
    fi
    
    # Is $1 good?  If so, sanitise and convert to seconds
    case "${1}" in
      (*[!0-9smhd]*|'')
        printf '%s\n' \
          "timeout: '${1}' is not valid.  Run 'timeout' for usage." >&2
        return 1
      ;;
      (*m)
        duration="${1//[!0-9]/}"; duration=$(( duration * 60 ))
      ;;
      (*h)
        duration="${1//[!0-9]/}"; duration=$(( duration * 60 * 60 ))
      ;;
      (*d)
        duration="${1//[!0-9]/}"; duration=$(( duration * 60 * 60 * 24 ))
      ;;
      (*)
        duration="${1//[!0-9]/}"
      ;;
    esac
    # shift so that the rest of the line is the command to execute
    shift

    # If 'perl' is available, it has a few pretty good one-line options
    # see: http://stackoverflow.com/q/601543
    if is_command perl; then
      perl -e '$s = shift; $SIG{ALRM} = sub { kill INT => $p; exit 77 }; exec(@ARGV) unless $p = fork; alarm $s; waitpid $p, 0; exit ($? >> 8)' "${duration}" "$@"
      #perl -MPOSIX -e '$SIG{ALRM} = sub { kill(SIGTERM, -$$); }; alarm shift; $exit = system @ARGV; exit(WIFEXITED($exit) ? WEXITSTATUS($exit) : WTERMSIG($exit));' "$@"

    # Otherwise we offer a shell based failover.
    # I tested a few, this one works nicely and is fairly simple
    # http://stackoverflow.com/a/24413646
    else
      # Run in a subshell to avoid job control messages
      ( "$@" &
        child=$! # Grab the PID of the COMMAND
        
        # Avoid default notification in non-interactive shell for SIGTERM
        trap -- "" SIGTERM
        ( sleep "${duration}"
          kill "${child}" 
        ) 2> /dev/null &
        
        wait "${child}"
      )
    fi
  }
fi

# Functions to quickly upper or lowercase some input
# perl option: perl -e "while (<STDIN>) { print lc; }"
# shellcheck disable=SC2120
tolower() {
  if [[ -n "${1}" ]] && [[ ! -r "${1}" ]]; then
    if (( BASH_VERSINFO >= 4 )); then
      printf -- '%s ' "${*,,}" | paste -sd '\0' -
    elif is_command awk; then
      printf -- '%s ' "$*" | awk '{print tolower($0)}'
    elif is_command tr; then
      printf -- '%s ' "$*" | tr '[:upper:]' '[:lower:]'
    else
      printf '%s\n' "tolower - no available method found" >&2
      return 1
    fi
  else
    if (( BASH_VERSINFO >= 4 )); then
      while read -r; do
        printf '%s\n' "${REPLY,,}"
      done
      [[ -n "${REPLY}" ]] && printf '%s\n' "${REPLY,,}"
    elif is_command awk; then
      awk '{print tolower($0)}'
    elif is_command tr; then
      tr '[:upper:]' '[:lower:]'
    else
      printf '%s\n' "tolower - no available method found" >&2
      return 1
    fi < "${1:-/dev/stdin}"
  fi
}

# perl option: perl -e "while (<STDIN>) { print uc; }"
# shellcheck disable=SC2120
toupper() {
  if [[ -n "${1}" ]] && [[ ! -r "${1}" ]]; then
    if (( BASH_VERSINFO >= 4 )); then
      printf -- '%s ' "${*^^}" | paste -sd '\0' -
    elif is_command awk; then
      printf -- '%s ' "$*" | awk '{print toupper($0)}'
    elif is_command tr; then
      printf -- '%s ' "$*" | tr '[:lower:]' '[:upper:]'
    else
      printf '%s\n' "toupper - no available method found" >&2
      return 1
    fi
  else
    if (( BASH_VERSINFO >= 4 )); then
      while read -r; do
        printf '%s\n' "${REPLY^^}"
      done
      [[ -n "${REPLY}" ]] && printf '%s\n' "${REPLY^^}"
    elif is_command awk; then
      awk '{print toupper($0)}'
    elif is_command tr; then
      tr '[:lower:]' '[:upper:]'
    else
      printf '%s\n' "toupper - no available method found" >&2
      return 1
    fi < "${1:-/dev/stdin}"
  fi
}

# Detect if our version of 'tput' is so old that it uses termcap syntax
# If this is the case, overlay it so that newer terminfo style syntax works
# This is a subset of a fuller gist
# https://gist.github.com/rawiriblundell/83ed9408a7e3032c780ed56b7c9026f2
# For performance we only implement if 'tput ce' (a harmless test) works
if tput ce 2>/dev/null; then
  tput() {
    ctput-null() { command tput "${@}" 2>/dev/null; }
    ctput() { command tput "${@}"; }
    case "${1}" in
      (bold)          ctput-null bold  || ctput md;;
      (civis)         ctput-null civis || ctput vi;;
      (cnorm)         ctput-null cnorm || ctput ve;;
      (cols)          ctput-null cols  || ctput co;;
      (dim)           ctput-null dim   || ctput mh;;
      (lines)         ctput-null lines || ctput li;;
      (setaf)
        case $(uname) in
          (FreeBSD)   ctput AF "${2}";;
          (OpenBSD)   ctput AF "${2}" 0 0;;
          (*)         ctput setaf "${2}";;
        esac
      ;;
      (setab)
        case $(uname) in
          (FreeBSD)   ctput AB "${2}";;
          (OpenBSD)   ctput AB "${2}" 0 0;;
          (*)         ctput setab "${2}";;
        esac
      ;;
      (sgr0)          ctput-null sgr0  || ctput me;;
      (*)             ctput "${@}";;
    esac
  }
fi

# Simple alternative for 'tree'
if ! exists tree; then
  tree() {
    find "${1:-.}" -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'
  }
fi

# Format the output of 'du'.  Found on the internet, unknown origin.
if ! exists treesize; then
  treesize() {
    du -k --max-depth=1 "${@}" | sort -nr | awk '
     BEGIN {
        split("KB,MB,GB,TB", Units, ",");
     }
     {
        u = 1;
        while ($1 >= 1024) {
           $1 = $1 / 1024;
           u += 1
        }
        $1 = sprintf("%.1f %s", $1, Units[u]);
        print $0;
     }
    '
  }
fi

# A function to remove whitespace either side of an input
# May require further testing and development
# shellcheck disable=SC2120
trim() {
  LC_CTYPE=C
  # If $1 is a readable file OR if $1 is blank, we process line by line
  if [[ -r "${1}" ]]||[[ -z "$1" ]]; then
    while read -r; do
      # Strip the left padding while reassigning 'REPLY' to 'line'
      line=${REPLY%"${REPLY##*[![:space:]]}"}
      # Print 'line' while stripping right padding
      printf -- '%s\n' "${line#"${line%%[![:space:]]*}"}"
    done < "${1:-/dev/stdin}"
  # Otherwise, we process whatever input arg(s) have been supplied
  else
    line=${*%"${*##*[![:space:]]}"}
    printf -- '%s\n' "${line%"${line##*[![:space:]]}"}"
  fi
}

# Provide 'up', so instead of e.g. 'cd ../../../' you simply type 'up 3'
up() {
  case "${1}" in
    (*[!0-9]*)  : ;;
    ("")        cd || return ;;
    (1)         cd .. || return ;;
    (*)         cd "$(eval "printf '../'%.0s {1..$1}")" || return ;;
  esac
}

# This is based on one of the best urandom+bash random integer scripts IMHO
# FYI: randInt is significantly faster
# https://unix.stackexchange.com/a/413890
urandInt() {
  local intCount rangeMin rangeMax range bytes t maxvalue mult hexrandom
  intCount="${1:-1}"
  rangeMin="${2:-1}"
  rangeMax="${3:-32767}"
  range=$(( rangeMax - rangeMin + 1 ))

  bytes=0
  t="${range}"
  while (( t > 0 )); do
    (( t=t>>8, bytes++ ))
  done

  maxvalue=$((1<<(bytes*8)))
  mult=$((maxvalue/range - 1))

  while (( i++ < intCount )); do
    while :; do
      hexrandom=$(dd if=/dev/urandom bs=1 count=${bytes} 2>/dev/null | xxd -p)
      (( 16#$hexrandom < range * mult )) && break
    done
    printf '%u\n' "$(( (16#$hexrandom%range) + rangeMin ))"
  done
}

# Get local weather and present it nicely
weather() {
  # We require 'curl' so check for it
  if ! exists curl; then
    printf '%s\n' "[ERROR] weather: This command requires 'curl', please install it."
    return 1
  fi

  # Handle our variables
  # If no arg is given, default to Wellington NZ
  local request curlArgs
  curlArgs="-H \"Accept-Language: ${LANG%_*}\" --compressed -m 10"
  case "${1}" in
    (-h|--help) request="wttr.in/:help" ;;
    (*)         request="wttr.in/${*:-Wellington}" ;;
  esac

  # If the width is less than 125 cols, automatically switch to narrow mode
  (( "${COLUMNS:-$(tput cols)}" < 125 )) && request+='?n'
  
  # Finally, make the request
  curl "${curlArgs}" "${request}" 2>/dev/null \
    || printf '%s\n' "[ERROR] weather: Could not connect to weather service."
}

# Function to display a list of users and their memory and cpu usage
# Non-portable swap: for file in /proc/*/status ; do awk '/VmSwap|Name/{printf $2 " " $3}END{ print ""}' $file; done | sort -k 2 -n -r
what() {
  # Start processing $1.  I initially tried coding this with getopts but it blew up
  if [[ "${1}" = "-c" ]]; then
    ps -eo pcpu,vsz,user | tail -n +2 | awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%\n", user, vsz[user]/1024, cpu[user]); }' | sort -k7 -rn
  elif [[ "${1}" = "-m" ]]; then
    ps -eo pcpu,vsz,user | tail -n +2 | awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%\n", user, vsz[user]/1024, cpu[user]); }' | sort -k4 -rn
  elif [[ -z "${1}" ]]; then
    ps -eo pcpu,vsz,user | tail -n +2 | awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%\n", user, vsz[user]/1024, cpu[user]); }'
  else
    printf '%s\n' "what - list all users and their memory/cpu usage (think 'who' and 'what')" "Usage: what [-c (sort by cpu usage) -m (sort by memory usage)]"
  fi
}

# Function to get the owner of a file
whoowns() {
  # First we try GNU-style 'stat'
  if stat -c '%U' "${1}" >/dev/null 2>&1; then
     stat -c '%U' "${1}"
  # Next is BSD-style 'stat'
  elif stat -f '%Su' "${1}" >/dev/null 2>&1; then
    stat -f '%Su' "${1}"
  # Otherwise, we failover to 'ls', which is not usually desireable
  else
    # shellcheck disable=SC2012
    ls -ld "${1}" | awk 'NR==1 {print $3}'
  fi
}

################################################################################
# genpasswd password generator
################################################################################
# Password generator function for when 'pwgen' or 'apg' aren't available
# Koremutake mode inspired by:
# https:#raw.githubusercontent.com/lpar/kpwgen/master/kpwgen.go
# http://shorl.com/koremutake.php
genpasswd() {
  # localise variables for safety
  local OPTIND pwdChars pwdDigit pwdNum pwdSet pwdKoremutake pwdUpper \
    pwdSpecial pwdSpecialChars pwdSyllables n t u v tmpArray

  # Default the vars
  pwdChars=10
  pwdDigit="false"
  pwdNum=1
  pwdSet="[:alnum:]"
  pwdKoremutake="false"
  pwdUpper="false"
  pwdSpecial="false"
  # shellcheck disable=SC1001
  pwdSpecialChars=(\! \@ \# \$ \% \^ \( \) \_ \+ \? \> \< \~)

  # Filtered koremutake syllables
  # http:#shorl.com/koremutake.php
  pwdSyllables=( ba be bi bo bu by da de di 'do' du dy fe 'fi' fo fu fy ga ge \
    gi go gu gy ha he hi ho hu hy ja je ji jo ju jy ka ke ko ku ky la le li \
    lo lu ly ma me mi mo mu my na ne ni no nu ny pa pe pi po pu py ra re ri \
    ro ru ry sa se si so su sy ta te ti to tu ty va ve vi vo vu vy bra bre \
    bri bro bru bry dra dre dri dro dru dry fra fre fri fro fru fry gra gre \
    gri gro gru gry pra pre pri pro pru pry sta ste sti sto stu sty tra tre \
    er ed 'in' ex al en an ad or at ca ap el ci an et it ob of af au cy im op \
    co up ing con ter com per ble der cal man est 'for' mer col ful get low \
    son tle day pen pre ten tor ver ber can ple fer gen den mag sub sur men \
    min out tal but cit cle cov dif ern eve hap ket nal sup ted tem tin tro
  )

  while getopts ":c:DhKn:SsUY" Flags; do
    case "${Flags}" in
      (c)  pwdChars="${OPTARG}";;
      (D)  pwdDigit="true";;
      (h)  printf '%s\n' "" "genpasswd - a poor sysadmin's pwgen" \
             "" "Usage: genpasswd [options]" "" \
             "Optional arguments:" \
             "-c [Number of characters. Minimum is 4. (Default:${pwdChars})]" \
             "-D [Require at least one digit (Default:off)]" \
             "-h [Help]" \
             "-K [Koremutake mode.  Uses syllables rather than characters, meaning more phonetical pwds." \
             "    Note: In this mode, character counts = syllable count and different defaults are used]" \
             "-n [Number of passwords (Default:${pwdNum})]" \
             "-s [Strong mode, seeds a limited amount of special characters into the mix (Default:off)]" \
             "-S [Stronger mode, complete mix of characters (Default:off)]" \
             "-U [Require at least one uppercase character (Default:off)]" \
             "-Y [Require at least one special character (Default:off)]" \
             "" "Note1: Broken Pipe errors, (older bash versions) can be ignored" \
             "Note2: If you get umlauts, cyrillic etc, export LC_ALL= to something like en_US.UTF-8"
           return 0;;
      (K)  pwdKoremutake="true";;
      (n)  pwdNum="${OPTARG}";;
      # Attempted to randomise special chars using 7 random chars from [:punct:] but reliably
      # got "reverse collating sequence order" errors.  Seeded 9 special chars manually instead.
      (s)  pwdSet="[:alnum:]#$&+/<}^%@";;
      (S)  pwdSet="[:graph:]";;
      (U)  pwdUpper="true";;
      (Y)  pwdSpecial="true";;
      (\?)  printf '%s\n' "[ERROR] genpasswd: Invalid option: $OPTARG.  Try 'genpasswd -h' for usage." >&2
            return 1;;
      (:)  echo "[ERROR] genpasswd: Option '-$OPTARG' requires an argument, e.g. '-$OPTARG 5'." >&2
           return 1;;
    esac
  done

  # We need to check that the character length is more than 4 to protect against
  # infinite loops caused by the character checks.  i.e. 4 character checks on a 3 character password
  if (( pwdChars < 4 )); then
    printf '%s\n' "[ERROR] genpasswd: Password length must be greater than four characters." >&2
    return 1
  fi

  if [[ "${pwdKoremutake}" = "true" ]]; then
    for (( i=0; i<pwdNum; i++ )); do
      n=0
      for int in $(randInt "${pwdChars:-7}" 1 $(( ${#pwdSyllables[@]} - 1 )) ); do
        tmpArray[n]=$(printf '%s\n' "${pwdSyllables[int]}")
        (( n++ ))
      done
      read -r t u v < <(randInt 3 0 $(( ${#tmpArray[@]} - 1 )) | paste -s -)
      #pwdLower is effectively guaranteed, so we skip it and focus on the others
      if [[ "${pwdUpper}" = "true" ]]; then
        tmpArray[t]=$(capitalise "${tmpArray[t]}")
      fi
      if [[ "${pwdDigit}" = "true" ]]; then
        while (( u == t )); do
          u="$(randInt 1 0 $(( ${#tmpArray[@]} - 1 )) )"
        done
        tmpArray[u]="$(randInt 1 0 9)"
      fi
      if [[ "${pwdSpecial}" = "true" ]]; then
        while (( v == t )); do
          v="$(randInt 1 0 $(( ${#tmpArray[@]} - 1 )) )"
        done
        randSpecial=$(randInt 1 0 $(( ${#pwdSpecialChars[@]} - 1 )) )
        tmpArray[v]="${pwdSpecialChars[randSpecial]}"
      fi
      printf '%s\n' "${tmpArray[@]}" | paste -sd '\0' -
    done
  else
    for (( i=0; i<pwdNum; i++ )); do
      n=0
      while read -r; do
        tmpArray[n]="${REPLY}"
        (( n++ ))
      done < <(tr -dc "${pwdSet}" < /dev/urandom | tr -d ' ' | fold -w 1 | head -n "${pwdChars}")
      read -r t u v < <(randInt 3 0 $(( ${#tmpArray[@]} - 1 )) | paste -s -)
      #pwdLower is effectively guaranteed, so we skip it and focus on the others
      if [[ "${pwdUpper}" = "true" ]]; then
        if ! printf '%s\n' "tmpArray[@]}" | grep "[A-Z]" >/dev/null 2>&1; then
          tmpArray[t]=$(capitalise "${tmpArray[t]}")
        fi
      fi
      if [[ "${pwdDigit}" = "true" ]]; then
        while (( u == t )); do
          u="$(randInt 1 0 $(( ${#tmpArray[@]} - 1 )) )"
        done
        if ! printf '%s\n' "tmpArray[@]}" | grep "[0-9]" >/dev/null 2>&1; then
          tmpArray[u]="$(randInt 1 0 9)"
        fi
      fi
      # Because special characters aren't sucked up from /dev/urandom,
      # we have no reason to test for them, just swap one in
      if [[ "${pwdSpecial}" = "true" ]]; then
        while (( v == t )); do
          v="$(randInt 1 0 $(( ${#tmpArray[@]} - 1 )) )"
        done
        randSpecial=$(randInt 1 0 $(( ${#pwdSpecialChars[@]} - 1 )) ) 
        tmpArray[v]="${pwdSpecialChars[randSpecial]}"
      fi
      printf '%s\n' "${tmpArray[@]}" | paste -sd '\0' -
    done
  fi
} 

################################################################################
# A separate password encryption tool, so that you can encrypt passwords of your own choice
cryptpasswd() {
  local inputPwd pwdSalt pwdKryptMode

  # If $1 is blank, print usage
  if [[ -z "${1}" ]]; then
    printf '%s\n' "" "cryptpasswd - a tool for hashing passwords" "" \
    "Usage: cryptpasswd [password to hash] [1|5|6|n]" \
    "    Crypt method can be set using one of the following options:" \
    "    '1' (MD5, default)" \
    "    '5' (SHA256)" \
    "    '6' (SHA512)" \
    "    'n' (NTLM)"
    return 0
  # Otherwise, assign our base variables
  else
    inputPwd="${1}"
    pwdSalt=$(tr -dc '[:alnum:]' < /dev/urandom | tr -d ' ' | fold -w 8 | head -n 1 | tolower) 2> /dev/null
  fi

  # We don't want to mess around with other options like bcrypt as it
  # requires more error handling than I can be bothered with
  # If the crypt mode isn't defined as 1, 5, 6 or n: default to 1
  case "${2}" in
    (n)
      printf '%s' "${inputPwd}" \
        | iconv -t utf16le \
        | openssl md4 \
        | awk '{print $2}' \
        | toupper
      return "$?"
    ;;
    (*)
      case "${2}" in
        (1|5|6) pwdKryptMode="${2}";;
        (*)     pwdKryptMode=1;;        # Default to MD5
      esac
      if is_command python; then
        #python -c 'import crypt; print(crypt.crypt('${inputPwd}', crypt.mksalt(crypt.METHOD_SHA512)))'
        python -c "import crypt; print crypt.crypt('${inputPwd}', '\$${pwdKryptMode}\$${pwdSalt}')"
      elif is_command perl; then
        perl -e "print crypt('${inputPwd}','\$${pwdKryptMode}\$${pwdSalt}\$')"
      elif is_command openssl; then
        printf '%s\n' "This was handled by OpenSSL which is only MD5 capable." >&2
        openssl passwd -1 -salt "${pwdSalt}" "${inputPwd}"
      else
        printf -- '%s\n' "No available method for this task" >&2
        return 1
      fi
    ;;
  esac
}

################################################################################
# genphrase passphrase generator
################################################################################
# A passphrase generator, because: why not?
# Note: This will only generate XKCD "Correct Horse Battery Staple" level phrases, 
# which arguably aren't that secure without some character randomisation.
# See the Schneier Method alternative i.e. "This little piggy went to market" = "tlpWENT2m"
genphrase() {
  # Some examples of methods to do this (fastest to slowest):
  # shuf:         printf '%s\n' "$(shuf -n 3 ~/.pwords.dict | tr -d "\n")"
  # perl:         printf '%s\n' "perl -nle '$word = $_ if rand($.) < 1; END { print $word }' ~/.pwords.dict"
  # sed:          printf "$s\n" "sed -n $((RANDOM%$(wc -l < ~/.pwords.dict)+1))p ~/.pwords.dict"
  # python:       printf '%s\n' "$(python -c 'import random, sys; print("".join(random.sample(sys.stdin.readlines(), "${phraseWords}")).rstrip("\n"))' < ~/.pwords.dict | tr -d "\n")"
  # oawk/nawk:    printf '%s\n' "$(for i in {1..3}; do sed -n "$(echo "$RANDOM" $(wc -l <~/.pwords.dict) | awk '{ printf("%.0f\n",(1.0 * $1/32768 * $2)+1) }')p" ~/.pwords.dict; done | tr -d "\n")"
  # gawk:         printf '%s\n' "$(awk 'BEGIN{ srand(systime() + PROCINFO["pid"]); } { printf( "%.5f %s\n", rand(), $0); }' ~/.pwords.dict | sort -k 1n,1 | sed 's/^[^ ]* //' | head -3 | tr -d "\n")"
  # sort -R:      printf '%s\n' "$(sort -R ~/.pwords.dict | head -3 | tr -d "\n")"
  # bash $RANDOM: printf '%s\n' "$(for i in $(<~/.pwords.dict); do echo "$RANDOM $i"; done | sort | cut -d' ' -f2 | head -3 | tr -d "\n")"

  # perl, sed, oawk/nawk and bash are the most portable options in order of speed.  The bash $RANDOM example is horribly slow, but reliable.  Avoid if possible.

  # First, double check that the dictionary file exists.
  if [[ ! -f ~/.pwords.dict ]] ; then
    # Test if we can download our wordlist, otherwise use the standard 'words' file to generate something usable
    if ! wget -T 2 https://raw.githubusercontent.com/rawiriblundell/dotfiles/master/.pwords.dict -O ~/.pwords.dict &>/dev/null; then
      # Alternatively, we could just use grep -v "[[:punct:]]", but we err on the side of portability
      LC_COLLATE=C grep -Eh '^[A-Za-z].{3,9}$' /usr/{,share/}dict/words 2>/dev/null | grep -v "'" > ~/.pwords.dict
    fi
  fi

  # Test we have the capitalise function available
  if ! type capitalise &>/dev/null; then
    printf '%s\n' "[ERROR] genphrase: 'capitalise' function is required but was not found." \
      "This function can be retrieved from https://github.com/rawiriblundell"
    return 1
  fi

  # localise our vars for safety
  local OPTIND  phraseWords phraseNum phraseSeed phraseSeedDoc seedWord totalWords

  # Default the vars
  phraseWords=3
  phraseNum=1
  phraseSeed="False"
  phraseSeedDoc="False"
  seedWord=

  while getopts ":hn:s:Sw:" Flags; do
    case "${Flags}" in
      (h)  printf '%s\n' "" "genphrase - a basic passphrase generator" \
             "" "Optional Arguments:" \
             "-h [help]" \
             "-n [number of passphrases to generate (Default:${phraseNum})]" \
             "-s [seed your own word.  Use 'genphrase -S' to read about this option.]" \
             "-S [explanation for the word seeding option: -s]" \
             "-w [number of random words to use (Default:${phraseWords})]" ""
           return 0;;
      (n)  phraseNum="${OPTARG}";;
      (s)  phraseSeed="True"
           seedWord="[${OPTARG}]";;
      (S)  phraseSeedDoc="True";;
      (w)  phraseWords="${OPTARG}";;
      (\?)  echo "ERROR: Invalid option: '-$OPTARG'.  Try 'genphrase -h' for usage." >&2
            return 1;;
      (:)  echo "Option '-$OPTARG' requires an argument. e.g. '-$OPTARG 10'" >&2
           return 1;;
    esac
  done
  
  # If -S is selected, print out the documentation for word seeding
  if [[ "${phraseSeedDoc}" = "True" ]]; then
    printf '%s\n' \
    "======================================================================" \
    "genphrase and the -s option: Why you would want to seed your own word?" \
    "======================================================================" \
    "One method for effectively using passphrases is known as 'root and extension.'" \
    "This can be expressed in a few ways, but in this context, it's to choose" \
    "at least two random words (your 'root') and to seed those two words" \
    "with a task specific word (your 'extension')." "" \
    "So let's take two words:" \
    "---" "pings genre" "---" "" \
    "Now if we capitalise both words to get TitleCasing, we meet the usual"\
    "UPPER and lowercase password requirements, as well as very likely" \
    "meeting the password length requirement: 'PingsGenre'" ""\
    "So then we add a task specific word: Let's say this passphrase is for" \
    "your online banking, so we add the word 'bank' into the mix and get:" \
    "'PingsGenrebank'" "" \
    "For social networking, you might have 'PingsGenreFBook' and so on." \
    "The random words are the same, but the task-specific word is the key." \
    "" "Problem is, this arguably isn't good enough.  According to Bruce Schneier" \
    "CorrectHorseBatteryStaple is not that secure.  Others argue otherwise." \
    "See: https://goo.gl/ZGlkfm and http://goo.gl/kunYbu." "" \
    "So we need to randomise those words, introduce some special characters," \
    "and some numbers.  'PingsGenrebank' becomes 'Pings{B4nk}Genre'" \
    "and likewise 'PingsGenreFBook' becomes '(FB0ok)GenrePings'." \
    "" "So, this is a very easy to remember system which meets most usual" \
    "password requirements, and it makes most lame password checkers happy." \
    "You could also argue that this borders on multi-factor auth" \
    "i.e. something you are/have/know = username/root/extension." \
    "" "genphrase will always put the seeded word in square brackets and if" \
    "possible it will randomise its location in the phrase, it's over to" \
    "you to make sure that your seeded word has numerals etc." "" \
    "Note: You can always use genphrase to generate the base phrase and" \
    "      then manually embellish it to your taste."
    return 0
  fi
  
  # Next test if a word is being seeded in
  if [[ "${phraseSeed}" = "True" ]]; then
    # If so, make space for the seed word
    ((phraseWords = phraseWords - 1))
  fi

  # Calculate the total number of words we might process
  totalWords=$(( phraseWords * phraseNum ))
  
  # Now generate the passphrase(s)
  # First we test to see if shuf is available.  This should now work with the
  # 'shuf' step-in function and 'rand' scripts available from https://github.com/rawiriblundell
  # Also requires the 'capitalise' function from said source.
  if is_command shuf; then
    # If we're using bash4, then use mapfile for safety
    if (( BASH_VERSINFO >= 4 )); then
      # Basically we're using shuf and awk to generate lines of random words
      # and assigning each line to an array element
      mapfile -t wordArray < <(shuf -n "${totalWords}" ~/.pwords.dict | awk -v w="${phraseWords}" 'ORS=NR%w?FS:RS')
    # This older method should be ok for this particular usage,
    # but otherwise is not a direct replacement for mapfile
    # See: http://mywiki.wooledge.org/BashFAQ/005#Loading_lines_from_a_file_or_stream
    else
      IFS=$'\n' read -d '' -r -a wordArray < <(shuf -n "${totalWords}" ~/.pwords.dict | awk -v w="${phraseWords}" 'ORS=NR%w?FS:RS')
    fi

    # Iterate through each line of the array
    for line in "${wordArray[@]}"; do
      # Convert the line to an array of its own and add any seed word
      # shellcheck disable=SC2206
      lineArray=( "${seedWord}" ${line} )
      if (( BASH_VERSINFO >= 4 )); then
        shuf -e "${lineArray[@]^}"
      else
        shuf -e "${lineArray[@]}" | capitalise
      fi | paste -sd '\0' -
    done
    return 0 # Prevent subsequent run of bash
  
  # Otherwise, we switch to bash.  This is the fastest way I've found to perform this
  else
    if ! exists rand; then
      printf '%s\n' "[ERROR] genphrase: This function requires the 'rand' external script, which was not found." \
        "You can get this script from https://github.com/rawiriblundell"
      return 1
    fi

    # We test for 'mapfile' which indicates bash4 or some step-in function
    if is_command mapfile; then
      # Create two arrays, one with all the words, and one with a bunch of random numbers
      mapfile -t dictArray < ~/.pwords.dict
      mapfile -t numArray < <(rand -M "${#dictArray[@]}" -r -N "${totalWords}")
    # Otherwise we take the classic approach
    else
      read -d '' -r -a dictArray < ~/.pwords.dict
      read -d '' -r -a numArray < <(rand -M "${#dictArray[@]}" -r -N "${totalWords}")
    fi

    # Setup the following vars for iterating through and slicing up 'numArray'
    loWord=0
    hiWord=$(( phraseWords - 1 ))

    # Now start working our way through both arrays
    while (( hiWord <= totalWords )); do
      # Group all the following output
      {
        # We print out a random number with each word, this allows us to sort
        # all of the output, which randomises the location of any seed word
        printf '%s\n' "${RANDOM} ${seedWord}"
        for randInt in "${numArray[@]:loWord:phraseWords}"; do
          if (( BASH_VERSINFO >= 4 )); then
            printf '%s\n' "${RANDOM} ${dictArray[randInt]^}"
          else
            printf '%s\n' "${RANDOM} ${dictArray[randInt]}" | capitalise
          fi
        done
      # Pass the grouped output for some cleanup
      } | sort | awk '{print $2}' | paste -sd '\0' -
      # Iterate our boundary vars up and loop again until completion
      # shellcheck disable=SC2034
      loWord=$(( hiWord + 1 ))
      hiWord=$(( hiWord + phraseWords ))
    done
  fi
}

################################################################################
# Figure out the correct TERM value
# Function to test indicated terminfo entries
termtest() {
  if is_command infocmp; then
    infocmp "${1}" &>/dev/null
    return "$?"
  else
    oldTerm="${TERM}"
    TERM="${1}"
    tput colors &>/dev/null
    rc="$?"
    TERM="${oldTerm}"
    return "${rc}"
  fi
}

# Firstly, we assume a PuTTY connection identified as 'putty-256color'
if [[ "${TERM}" = "putty-256color" ]]; then
  # We check whether an appropriate terminfo entry exists
  # If not, failover to 'xterm-256color'
  termtest putty-256color || TERM=xterm-256color
# If we're not using 'putty-256color', then we want 'xterm-256color'
else
  TERM=xterm-256color
fi

# Next, we test for a 'xterm-256color' terminfo entry
# If not, we set up ~/.terminfo appropriately (usually Solaris)
if [[ "${TERM}" = "xterm-256color" ]]; then
  if ! termtest xterm-256color; then
    if is_command tic; then
      mkdir -p "${HOME}"/.terminfo
      print-xterm-256color > "${HOME}"/.terminfo/xterm-256color
      TERMINFO="${HOME}"/.terminfo
      export TERMINFO
      tic "${HOME}"/.terminfo/xterm-256color 2>/dev/null
      TERM=xterm-256color
    else
      printf '%s\n' "'tic' is required to setup xterm-256color but was not found" \
        "Usually this can be found in the 'ncurses' package"
      # Set a dummy TERM to invoke the next block
      TERM=pants
    fi
  fi
fi

# Finally, if we get to this point, we take what we can get
if ! string-contains 256color "${TERM}"; then
  for termType in xterm-color xtermc dtterm sun-color xterm; do
    if termtest "${termType}"; then
      TERM="${termType}"
      break
    fi
  done
fi

# Finally, lock in the TERM setting
export TERM
################################################################################
# Standardise the Command Prompt
# NOTE for customisation: Any non-printing escape characters must be enclosed, 
# otherwise bash will miscount and get confused about where the prompt starts.  
# All sorts of line wrapping weirdness and prompt overwrites will then occur.  
# This is why all the escape codes have '\]' enclosing them.  Don't mess with that.

# First, we map some basic colours:
ps1Blk="\[$(tput setaf 0)\]"                    # Black - \[\e[0;30m\]
ps1Red="\[$(tput bold)\]\[$(tput setaf 9)\]"    # Bold Red - \[\e[1;31m\]
ps1Grn="\[$(tput setaf 10)\]"                   # Normal Green - \[\e[0;32m\]
ps1Ylw="\[$(tput bold)\]\[$(tput setaf 11)\]"   # Bold Yellow - \[\e[1;33m\]
ps1Blu="\[$(tput setaf 32)\]"                   # Blue - \[\e[38;5;32m\]
ps1Mag="\[$(tput bold)\]\[$(tput setaf 13)\]"   # Bold Magenta - \[\e[1;35m\]
ps1Cyn="\[$(tput bold)\]\[$(tput setaf 14)\]"   # Bold Cyan - \[\e[1;36m\]
ps1Wte="\[$(tput bold)\]\[$(tput setaf 15)\]"   # Bold White - \[\e[1;37m\]
ps1Ora="\[$(tput setaf 208)\]"                  # Orange - \[\e[38;5;208m\]
ps1Rst="\[$(tput sgr0)\]"                       # Reset text - \[\e[0m\]

# Map out some block characters
# shellcheck disable=SC2034
block100="\xe2\x96\x88"  # u2588\0xe2 0x96 0x88 Solid Block 100%
block75="\xe2\x96\x93"   # u2593\0xe2 0x96 0x93 Dark shade 75%
block50="\xe2\x96\x92"   # u2592\0xe2 0x96 0x92 Half shade 50%
block25="\xe2\x96\x91"   # u2591\0xe2 0x96 0x91 Light shade 25%

# Put those block characters in ascending and descending triplets
blockAsc="$(printf '%b\n' "${block25}${block50}${block75}")"
blockDwn="$(printf '%b\n' "${block75}${block50}${block25}")"

setprompt-help() {
  printf -- '%s\n' "setprompt - configure state and colourisation of the bash prompt" ""
  printf '\t%s\n' "Usage: setprompt [-ahfmrs|rand|safe|[0-255]] [rand|[0-255]]" ""
  printf '\t%s\n' "Options:" \
    "  -a    Automatic type selection (width based)" \
    "  -g    Enable/disable git branch in the first text block" \
    "  -h    Help, usage information" \
    "  -f    Full prompt" \
    "  -m    Minimal prompt" \
    "  -r    Restore prompt colours to defaults" \
    "  -s    Simplified prompt" \
    "  rand  Select a random colour.  Can be used for 1st and 2nd colours" \
    "        e.g. 'setprompt rand rand'" \
    "  safe  Sets 1st and 2nd colours to white.  In case of weird behaviour" \
    "" \
    "The first and second parameters will accept human readable colour codes." \
    "These are represented in short and full format e.g." \
    "For 'blue', you can enter 'bl', 'Bl', 'blue' or 'Blue'." \
    "This applies for:" \
    "Black, Red, Green, Yellow, Blue, Magenta, Cyan, White and Orange." \
    "ANSI Numerical codes (0-255) can also be supplied" \
    "e.g. 'setprompt 143 76'." \
    "" \
    "256 colours is assumed.  If you find issues, run 'setprompt safe'." \
    "" \
    "'setprompt -a' enables auto width-based prompt mode selection." \
    "If less than 60 columns is detected, the prompt is set to minimal mode." \
    "If less than 80 columns is detected, the prompt is set to simple mode." \
    "When the columns exceed 80, the prompt is set to the full mode."
  return 0
}

# If we want to define our colours with a dotfile, we load it here
# shellcheck disable=SC1090
[[ -f "${HOME}/.setpromptrc" ]] && . "${HOME}/.setpromptrc"

setprompt() {
  # Let's setup some default primary and secondary colours for root/sudo
  if (( EUID == 0 )); then
    ps1Pri="${ps1Red}"
    ps1Sec="${ps1Red}"
    ps1Block="${blockAsc}"
    ps1Char='#'
  fi

  case "${1}" in
    (-a|--auto)             export PS1_MODE=Auto;;
    (-g|--git)
      case "${PS1_GIT_MODE}" in
        (True)  PS1_GIT_MODE=False ;;
        (False) PS1_GIT_MODE=True ;;
        (''|*)  PS1_GIT_MODE=True ;;
      esac
      export PS1_GIT_MODE
    ;;
    (-h|--help)             setprompt-help; return 0;;
    (-f|--full)             export PS1_MODE=Full;;
    (-m|--mini)             export PS1_MODE=Minimal;;
    (-r|--reset)
      if [[ -r "${HOME}/.setpromptrc" ]]; then
        . "${HOME}/.setpromptrc"
      else
        ps1Pri="${ps1Red}"
        ps1Sec="${ps1Grn}"
      fi
    ;;
    (-s|--simple)           export PS1_MODE=Simple;;
    (b|B|black|Black)       ps1Pri="${ps1Blk}";;
    (r|R|red|Red)           ps1Pri="${ps1Red}";;
    (g|G|green|Green)       ps1Pri="${ps1Grn}";;
    (y|Y|yellow|Yellow)     ps1Pri="${ps1Ylw}";;
    (bl|Bl|blue|Blue)       ps1Pri="${ps1Blu}";;
    (m|M|magenta|Magenta)   ps1Pri="${ps1Mag}";;
    (c|C|cyan|Cyan)         ps1Pri="${ps1Cyn}";;
    (w|W|white|White)       ps1Pri="${ps1Wte}";;
    (o|O|orange|Orange)     ps1Pri="${ps1Ora}";;
    (rand)
      PS1_COLOUR_PRI=$((RANDOM%255))
      ps1Pri="\[$(tput setaf ${PS1_COLOUR_PRI})\]"
    ;;
    (safe)
      ps1Pri="${ps1Wte}"
      ps1Sec="${ps1Wte}"      
    ;;
    (*[0-9]*)
      if (( "${1//[^0-9]/}" > 255 )); then
        setprompt-help; return 1
      else
        ps1Pri="\[\e[38;5;${1//[^0-9]/}m\]"
      fi
    ;;
    (-|_)                   : #no-op ;;
  esac

  case "${2}" in
    (b|B|black|Black)       ps1Sec="${ps1Blk}";;
    (r|R|red|Red)           ps1Sec="${ps1Red}";;
    (g|G|green|Green)       ps1Sec="${ps1Grn}";;
    (y|Y|yellow|Yellow)     ps1Sec="${ps1Ylw}";;
    (bl|Bl|blue|Blue)       ps1Sec="${ps1Blu}";;
    (m|M|magenta|Magenta)   ps1Sec="${ps1Mag}";;
    (c|C|cyan|Cyan)         ps1Sec="${ps1Cyn}";;
    (w|W|white|White)       ps1Sec="${ps1Wte}";;
    (o|O|orange|Orange)     ps1Sec="${ps1Ora}";;
    (rand)
      PS1_COLOUR_SEC=$((RANDOM%255))
      ps1Sec="\[$(tput setaf ${PS1_COLOUR_SEC})\]"
    ;;
    (*[0-9]*)
      if (( "${2//[^0-9]/}" > 255 )); then
        setprompt-help; return 1
      else
        ps1Sec="\[\e[38;5;${2//[^0-9]/}m\]"
      fi
    ;;
    (-|_)                   : #no-op ;;
  esac

  case "${3}" in
    (a|A|asc|Asc)           ps1Block="${blockAsc}";;
    (d|D|dwn|Dwn)           ps1Block="${blockDwn}";;
  esac

  # Setup sane defaults for the following variables
  export "${PS1_MODE:=Auto}"
  : "${ps1Pri:=$ps1Red}"
  : "${ps1Sec:=$ps1Grn}"
  : "${ps1Block:=$blockDwn}"
  : "${ps1Char:='$'}"
  ps1Triplet="${ps1Pri}${ps1Block}"
  ps1Main="${ps1Sec}[\u@\h${ps1Rst} \W${ps1Sec}]${ps1Rst}${ps1Char}"

  # If PS1_MODE is set to Auto, it figures out the appropriate mode to use
  if [[ "${PS1_MODE}" = "Auto" ]]; then
    # We store the fact that we're in auto mode
    export PS1_AUTO=True
    if (( "${COLUMNS:-$(tput cols)}" < 60 )); then
      export PS1_MODE=Minimal
    elif (( "${COLUMNS:-$(tput cols)}" > 80 )); then
      export PS1_MODE=Full
    else
      export PS1_MODE=Simple
    fi
  else
    export PS1_AUTO=False
  fi

  # Throw it all together, based on the selected mode
  # shellcheck disable=SC1117
  case "${PS1_MODE}" in
    (Minimal)
      export PS1="${ps1Triplet}${ps1Rst}${ps1Char} "
    ;;
    (Simple)
      export PS1="${ps1Triplet}${ps1Main} "
    ;;
    (Full)
      if [[ "${PS1_GIT_MODE}" = "True" ]]; then
        if is_gitdir; then
          if [[ -z "${GIT_BRANCH}" ]]; then
            if is_gitdir; then
              GIT_BRANCH="$(git branch 2>/dev/null| sed -n '/\* /s///p')"
            fi
          fi
          : "[${GIT_BRANCH:-UNKNOWN}]"
        else
          : "[NOT-GIT]"
        fi
      else
        : "[\$(date +%y%m%d/%H:%M)]"
      fi
      PS1="${ps1Triplet}${_}${ps1Rst}${ps1Main} "
      export PS1
    ;;
  esac

  # If we're in auto mode, now that PS1 is set, we need to reset PS1_MODE
  [[ "${PS1_AUTO}" = "True" ]] && export PS1_MODE=Auto
  
  # After each command, append to the history file and reread it
  # This attempts to keep history sync'd across multiple sessions
  history -a; history -c; history -r
}

# Useful for debugging
export PS4='+${BASH_SOURCE}:${LINENO}:${FUNCNAME:-}: '

################################################################################
# Set the PROMPT_COMMAND
# This updates the terminal emulator title and the prompt
PROMPT_COMMAND="settitle; setprompt"
################################################################################
