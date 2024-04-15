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
#       This requires/explains some seemingly less-than-optimal or verbose code

# Source global definitions
# shellcheck disable=SC1091
[[ -f /etc/bashrc ]] && . /etc/bashrc

# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

# Set umask for new files
umask 027

################################################################################
# Download and source the latest version of this .bashrc
bashrc_update() {
  local remote_source
  remote_source='https://raw.githubusercontent.com/rawiriblundell/dotfiles/master/.bashrc'
  if command -v curl >/dev/null 2>&1; then
    printf -- '%s' "Downloading with curl..."
    curl -s "${remote_source}" > "${HOME}/.bashrc.new"
  elif command -v wget >/dev/null 2>&1; then
    printf -- '%s' "Downloading with wget..."
    wget "${remote_source}" > "${HOME}/.bashrc.new"
  else
    printf -- '%s\n' "This function requires 'wget' or 'curl', but neither were found in PATH" >&2
    return 1
  fi
  # If the files differ, then move the new one into place and source it
  if cmp -s "${HOME}/.bashrc" "${HOME}/.bashrc.new"; then
    printf -- '%s\n' " local version is up to date."
  else
    printf -- '%s\n' " updating and loading..."
    mv -v "${HOME}/.bashrc" "${HOME}/.bashrc.$(date +%Y%m%d)"
    mv -v "${HOME}/.bashrc.new" "${HOME}/.bashrc"
    # shellcheck disable=SC1090
    source "${HOME}/.bashrc"
  fi
}

# A function to update the PATH variable
# shellcheck disable=SC2120
set_env_path() {
  local path dir new_path
  
  # If we have any args, feed them into ~/.pathrc
  if (( "${#}" > 0 )); then
    touch "${HOME}/.pathrc"
    # shellcheck disable=SC2048
    for path in ${*}; do
      if [[ -d "${path}" ]]; then
        if ! grep -q "${path}" "${HOME}/.pathrc"; then
          printf -- '%s\n' "${path}" >> "${HOME}/.pathrc"
        fi
      fi
    done
  fi

  # Open an array of potential PATH members
  # This allows us to bias bindirs for a better experience on Solaris and MacOS
  pathArray=(
    /usr/gnu/bin /usr/xpg6/bin /usr/xpg4/bin /usr/local/opt/coreutils/libexec/gnubin
    /usr/local/opt/gnu-sed/libexec/gnubin /usr/local/opt/grep/libexec/gnubin
    /usr/kerberos/bin /usr/kerberos/sbin /bin /sbin /usr/bin /usr/sbin
    /usr/local/bin /usr/local/sbin /usr/local/opt/texinfo/bin
    /usr/local/opt/libxml2/bin /usr/X11/bin /opt/csw/bin /opt/csw/sbin /opt/sfw/bin
    /opt/sfw/sbin /opt/X11/bin /usr/sfw/bin /usr/sfw/sbin /usr/games
    /usr/local/games /snap/bin "${HOME}/bin" "${HOME}/go/bin" /usr/local/go/bin
    "${HOME}/.cargo" "${HOME}/.cargo/bin" /Library/TeX/texbin "${HOME}/.fzf/bin"
    /usr/local/opt/fzf/bin "${HOME}/.bash-my-aws/bin"
  )
 
  # If Android Home exists, add more dirs
  if [[ -d "${HOME}"/Library/Android/sdk ]]; then
    export ANDROID_HOME="${HOME}"/Library/Android/sdk
    pathArray+=( "${ANDROID_HOME}"/tools )
    pathArray+=( "${ANDROID_HOME}"/tools/bin )
    pathArray+=( "${ANDROID_HOME}"/emulator )
    pathArray+=( "${ANDROID_HOME}"/platform-tools )
  fi    
  
  # Add anything from .pathrc, /etc/paths and /etc/paths.d/*
  # i.e. OSX, because path_helper can be slow...
  while read -r; do
    pathArray+=( "${REPLY}" )
  done < <(find "${HOME}/.pathrc" /etc/paths /etc/paths.d -type f -exec cat {} \; 2>/dev/null)

  # Iterate through the array and build the new_path variable using found paths
  new_path=
  for dir in "${pathArray[@]}"; do
    # If it's already in new_path, skip on to the next dir
    case "${new_path}" in 
      (*:${dir}:*|*:${dir}$) continue ;; 
    esac
    [[ -d "${dir}" ]] && new_path="${new_path}:${dir}"
  done

  # Now assign our freshly built new_path variable, removing any leading colon
  PATH="${new_path#:}"

  # Finally, export the PATH
  export PATH
}

# Run the function to straighten out PATH
# shellcheck disable=SC2119
set_env_path

# Functionalise 'command -v' to allow 'if get_command [command]' idiom
get_command() {
  local errcount cmd
  case "${1}" in
    (-v|--verbose)
      shift 1
      errcount=0
      for cmd in "${@}"; do
        command -v "${cmd}" || {
          printf -- '%s\n' "${cmd} not found" >&2
          (( ++errcount ))
        }
      done
      (( errcount == 0 )) && return 0
    ;;
    ('')
      printf -- '%s\n' "get_command [-v|--verbose] list of commands" \
        "get_command will emit return code 1 if any listed command is not found" >&2
      return 0
    ;;
    (*)
      errcount=0
      for cmd in "${@}"; do
        command -v "${1}" >/dev/null 2>&1 || (( ++errcount ))
      done
      (( errcount == 0 )) && return 0
    ;;
  esac
  # If we get to this point, we've failed
  return 1
}

# If EUID isn't set, then set it
# Note that 'id -u' is now mostly portable here due to the alignment of xpg4 above
: "${EUID:-$(id -u)}"
readonly EUID; export EUID

# If HOSTNAME isn't set, then set it
: "${HOSTNAME:-$(hostname)}"
readonly HOSTNAME; export HOSTNAME

# If HOME isn't set, then set it
if [[ -z "${HOME}" ]]; then
  HOME=$(getent passwd | awk -F':' -v EUID="${EUID}" '$3 == EUID{print $6}')
  readonly HOME; export HOME
fi

# Create an array of potential dotfiles
dotfiles=(
  "${HOME}/.bash_aliases"
  "${HOME}/.bash_functions"
  "${HOME}/.proxyrc"
  "${HOME}/.workrc"
  "${HOME}/.fzf/shell/completion.bash"
  "${HOME}/.fzf/shell/key-bindings.bash"
  /usr/local/opt/fzf/shell/completion.bash
  /usr/local/opt/fzf/shell/key-bindings.bash
  "${HOME}/.bash-my-aws/aliases"
  "${HOME}/.bash-my-aws/bash_completion.sh"
)

# Work through our list of dotfiles, if a match is found, load it
# shellcheck source=/dev/null
for dotfile in "${dotfiles[@]}"; do
  [[ -r "${dotfile}" ]] && . "${dotfile}"
done

unset dotfiles; unset -v dotfile

# If pass is present, we set our environment variables
if get_command pass; then
  # If 'gpg2' is present, we need to set $GPG
  # This prevents 'pass' from confusing gpg1 and gpg2 on e.g. Ubuntu
  # While leaving other configurations alone (e.g. OSX brew "gpg" is gpg2)
  # May require change to test e.g. $(gpg --version | awk 'NR==1{print $3}')
  get_command gpg2 && GPG="gpg2"
  get_command gpg2 && alias gpg='gpg2'
  GPG_OPTS=( "--quiet" "--yes" "--compress-algo=none" "--no-encrypt-to" )
  GPG_TTY="${GPG_TTY:-$(tty 2>/dev/null)}"
  readonly GPG GPG_OPTS GPG_TTY
  export GPG GPG_OPTS GPG_TTY
fi

# If an ssh private key is found, spin up an agent and load the key(s)
if file "${HOME}/.ssh/"* | grep "private key" >/dev/null 2>&1; then
  if [[ ! -S "${HOME}/.ssh/"ssh_auth_sock ]] || ! pgrep ssh-agent >/dev/null 2>&1; then
    printf -- '\n======> %s\n\n' "Private ssh keys found, setting up ssh-agent..."
    eval "$(ssh-agent -s)"
    ln -sf "${SSH_AUTH_SOCK}" "${HOME}/.ssh/"ssh_auth_sock
  fi
  export SSH_AUTH_SOCK="${HOME}/.ssh/"ssh_auth_sock
  ssh-add -l > /dev/null || ssh-add
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
HISTIGNORE='ls:bg:fg:history*:yore*:redo*:exit'
 
# For setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=5000
HISTFILESIZE=5000

# Define a number of cd's to keep track of
CDHISTSIZE=30

# If we're disconnected, capture whatever is in history
trap 'history -a' SIGHUP

# Disable ctrl+s (XOFF)
stty ixany
stty ixoff -ixon

# Minimise the risk of pastejacking
# See: https://lists.gnu.org/archive/html/bug-bash/2019-02/msg00057.html
set enable-bracketed-paste On

# Make Tab cycle between possible completions
# Cycle forward: Tab
# Cycle backward: Shift-Tab
bind TAB:menu-complete
bind '"\e[Z": menu-complete-backward'

################################################################################
# Programmable Completion (Tab Completion)

# Enable programmable completion features
if ! shopt -oq posix; then
  # Define a list of completion files in order of preference
  # This is Linux -> OSX Brew -> older Linux/maybe Solaris -> maybe older Brew
  compfiles=(
    /etc/bash_completion
    /usr/local/etc/profile.d/bash_completion.sh
    /usr/share/bash-completion/bash_completion
    /usr/local/etc/bash_completion
  )

  for compfile in "${compfiles[@]}"; do
    if [[ -r "${compfile}" ]]; then
      compfile_found=true
      # shellcheck source=/dev/null
      . "${compfile}" 
      break
    fi
  done
fi

unset compfiles; unset -v compfile

# If we haven't found a compfile, try to manually load any
# found files in /etc/bash_completion.d
if [[ "${compfile_found}" != "true" ]]; then
  # 'have()' is sometimes unset by one/all of the above completion files
  # Which can upset the loading of the following conf frags
  # We temporarily provide a variant of it using get_command()
  have() {
    unset -v have 
    get_command "${1}" && have=yes
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
fi

# Fix 'cd' tab completion
complete -d cd

# Emulate the Alt-h helper from the fish shell
# Example: cat [alt-h] -> man cat
alt_h() {
  local _alth_first_word _alth_lookup_cmd
  export ALTH_SC="$(tput sc)"

  _alth_first_word=${READLINE_LINE%% *}
  if (( READLINE_POINT > ${#_alth_first_word} )); then
    # grab the string up to the cursor. e.g. "df {} | less" where {} is the cursor looks up df.
    _alth_lookup_cmd=${READLINE_LINE::$READLINE_POINT}
    # remove previous commands from the left
    _alth_lookup_cmd=${_alth_lookup_cmd##*[;|&]}
    # remove leading space if it exists (only a single one though)
    _alth_lookup_cmd=${_alth_lookup_cmd# }
    #remove arguments to the current command from the right
    _alth_lookup_cmd=${_alth_lookup_cmd%% *}
  else
    # if the cursor is at the beginning of the line, look up the first word
    _alth_lookup_cmd=$_alth_first_word 
  fi

  if get_command tldr; then
    tldr "${_alth_lookup_cmd}"
  else
    man "${_alth_lookup_cmd}"
  fi
}

bind -x '"\eh":alt_h'

################################################################################
# OS specific tweaks
# TO-DO: export as an environment var like OSSTR to minimise calls to uname

case "$(uname)" in
  (SunOS)
    # Function to essentially sort out "Terminal Too Wide" issue in vi on Solaris
    vi() {
      local origWidth
      origWidth="${COLUMNS:-$(tput cols)}"
      (( origWidth > 160 )) && stty columns 160
      command vi "$*"
      stty columns "${origWidth}"
    }
  ;;
  (Linux)
    # Correct backspace behaviour for some troublesome Linux servers that don't abide by .inputrc
    tty --quiet && stty erase '^?'
  ;;
  (Darwin)
    # OSX's 'locate' is garbage and updated weekly, 'mdfind' is updated near real-time
    alias locate='mdfind'
    # If we have GNU coreutils via brew, we should have the man pages too
    if [[ -d "/usr/local/opt/coreutils/libexec/gnuman" ]]; then
      case "${MANPATH}" in 
        (/usr/local/opt/coreutils/libexec/gnuman:*) : ;;
        (*)
          MANPATH="/usr/local/opt/coreutils/libexec/gnuman:${MANPATH:-/usr/share/man}"
        ;;
      esac
    fi
  ;;
esac
  
# I haven't used HP-UX in a while, but just to be sure
# we fix the backspace quirk for xterm
if [[ "$(uname -s)" = "HP-UX" ]] && [[ "${TERM}" = "xterm" ]]; then
  stty intr ^c
  stty erase ^?
fi

# If we're using WSL2, we are likely to have vscode on our Windows host
# Let's setup a couple of env vars and a function
if [[ -e /mnt/c/Users ]]; then
  WSL2_USER="$(tr -d '\r' < <(/mnt/c/Windows/System32/cmd.exe /c "echo %USERNAME%" 2>/dev/null))"
  WSL2_LOCALAPPDATA="/mnt/c/Users/${WSL2_USER}/AppData/Local"
  readonly WSL2_USER WSL2_LOCALAPPDATA
  export WSL2_USER WSL2_LOCALAPPDATA
  vscode() {
    ${WSL2_LOCALAPPDATA}/Programs/Microsoft\ VS\ Code/Code.exe "${@}"
  }
fi

################################################################################
# Aliases

# Test if our version of 'diff' supports the '-W' argument.  If so, we
# enable wide diff, which is handy for side-by-side i.e. diff -y or sdiff
if diff -W 100 <(echo a) <(echo a) >/dev/null 2>&1; then
  alias diff='diff -W $(( "${COLUMNS:-$(tput cols)}" - 2 ))'
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

# Straighten out $EDITOR and alias 'vi' by order of preference: 
# nvim -> vim -> vi
if get_command nvim; then
  EDITOR="$(get_command -v nvim)"
  alias vi='nvim'
elif get_command vim; then
  EDITOR="$(get_command -v vim)"
  alias vi='vim'
else
  EDITOR="$(get_command -v vi)"
fi
export EDITOR

# It's increasingly rare to find a version of 'sdiff' that doesn't have '-w'
# So we simply test for 'sdiff's existence and setup the alias if found
# As with 'diff' this sets the available width
if get_command sdiff; then
  alias sdiff='sdiff -w $(( "${COLUMNS:-$(tput cols)}" - 2 ))'
else
  alias sdiff='diff -y -w $(( "${COLUMNS:-$(tput cols)}" - 2 ))'
fi

# It looks like blindly asserting the following upsets certain 
# Solaris versions of *grep.  So we throw in an extra check
if echo "test" | grep --color=auto test &>/dev/null; then
  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

# Switch to the last used branch in git
alias lastbranch='git checkout @{-1}'

################################################################################
# Colours

# Generated using https://dom111.github.io/grep-colors
GREP_COLORS='sl=49;39:cx=49;39:mt=49;31;1:fn=49;32:ln=49;33:bn=49;33:se=1;36'
#GREP_OPTIONS='--color=auto' # Deprecated

# Generated by hand, referencing http://linux-sxs.org/housekeeping/lscolors.html
# and https://geoff.greer.fm/lscolors/
LS_COLORS='di=1;32:ln=1;30;47:so=30;45:pi=30;45:ex=1;31:bd=30;46:cd=30;46:su=30'
LS_COLORS="${LS_COLORS};41:sg=30;41:tw=30;41:ow=30;41:*.rpm=1;31:*.deb=1;31"
LSCOLORS=CxahafafBxagagabababab

export GREP_COLORS LS_COLORS LSCOLORS

# Check for dircolors and if found, process .dircolors
# This sets up colours for 'ls' via LS_COLORS
if [[ -z "${LS_COLORS}" ]] && get_command dircolors; then
  if [[ -r ~/.dircolors ]]; then
    eval "$(dircolors -b ~/.dircolors)"
  elif [[ -r /etc/DIR_COLORS ]] ; then
    eval "$(dircolors -b /etc/DIR_COLORS)"
  else
    eval "$(dircolors -b)"
  fi
fi

LESS_TERMCAP_mb=$'\E[1;31m'         # begin blink
LESS_TERMCAP_md=$'\E[1;36m'         # begin bold
LESS_TERMCAP_me=$'\E[0m'            # reset bold/blink
LESS_TERMCAP_se=$'\E[0m'            # reset reverse video
LESS_TERMCAP_so=$'\E[38;5;246m'     # begin reverse video
LESS_TERMCAP_ue=$'\E[0m'            # reset underline
LESS_TERMCAP_us=$'\E[04;38;5;146m'  # begin underline
export LESS_TERMCAP_mb LESS_TERMCAP_md LESS_TERMCAP_me LESS_TERMCAP_se
export LESS_TERMCAP_so LESS_TERMCAP_ue LESS_TERMCAP_us

################################################################################
# Functions

# A helper for git information in 'setprompt()' and others
_set_git_branch_var() {
  PS1_GIT_MODE=True
  is_gitdir || { PS1_GIT_MODE=False; return; }

  #GIT_BRANCH="$(git branch 2>/dev/null| sed -n '/\* /s///p')"
  GIT_BRANCH="$(git branch --show-current)"
  # Sometimes you're in a git dir but 'git branch' returns nothing
  # In this rare instance, we pluck the info from 'git status'
  if (( "${#GIT_BRANCH}" == 0 )); then
    GIT_BRANCH="$(git status 2>&1 | awk '/On branch/{print $3}')"
  fi
  #Finally, we failover to UNKNOWN
  GIT_BRANCH="${GIT_BRANCH:-UNKNOWN}"
  export GIT_BRANCH
}

# Because you never know what crazy systems are out there
get_command apropos || apropos() { man -k "$*"; }

# Smoosh the gap between 'aws-cli' and 'aws-vault'
if command -v aws >/dev/null 2>&1; then
  aws() {
    case "${1}" in
      (vault)
        if command -v aws-vault; then
          shift 1
          command aws-vault "${@}"
        else
          printf -- '%s\n' "aws-vault not found in PATH" >&2
          return 1
        fi
      ;;
      (*) command aws "${@}" ;;
    esac
  }
  AWS_DEFAULT_OUTPUT=json
  AWS_DEFAULT_REGION=ap-southeast-2
  AWS_VAULT_BACKEND="${AWS_VAULT_BACKEND:-file}"
  export AWS_DEFAULT_OUTPUT AWS_DEFAULT_REGION AWS_VAULT_BACKEND
fi

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
    printf -- '%s\n' "Usage:  capitalise string" ""
    printf -- '\t%s\n' "Capitalises the first character of STRING and/or its elements."
    return 0
  # Disallow both piping in strings and declaring strings
  elif [[ ! -t 0 ]] && [[ -n "${1}" ]]; then
    printf -- '%s\n' "[ERROR] capitalise: Please select either piping in or declaring a string to capitalise, not both."
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
        printf -- '%s\n' ""
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
    for inString in "${@}"; do
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

# A function that helps to manage the CDHIST array
_cdhist() {
  local CDHISTSIZE_CUR
  CDHISTSIZE_CUR="${#CDHIST[@]}"
  case "${1}" in
    (list)
      local i j
      i="${#CDHIST[@]}"
      j="0"
      until (( i == 0 )); do
        printf -- '%s\n' "-${i} ${CDHIST[j]}"
        (( --i )); (( ++j ))
      done
    ;;
    (append)
      local element
      # Ensure that we're working with a directory
      [[ -d "${2}" ]] || return 1
      # Ensure that we're not adding a duplicate entry
      # This array should be small enough to loop over without any impact
      for element in "${CDHIST[@]}"; do
        [[ "${element}" = "${2}" ]] && return 0
      done
      # Ensure that we remain within CDHISTSIZE by rotating out older elements
      if (( CDHISTSIZE_CUR >= "${CDHISTSIZE:-30}" )); then
        CDHIST=( "${CDHIST[@]:1}" )
      fi
      # Add the newest element
      CDHIST+=( "${2}" )
    ;;
    (select)
      local cdhist_target offset
      offset="${2}"
      cdhist_target="$(( CDHISTSIZE_CUR + offset ))"
      printf -- '%s\n' "${CDHIST[cdhist_target]}"
    ;;
  esac
}

# If CDHIST is empty, try to pre-load it from bash_history
_cdhist_skel() {
  [[ -r "${HOME}/.bash_history" ]] || return 1
  awk '/^cd \//{ if (!a[$0]++) print;}' "${HOME}/.bash_history" | 
    cut -d ' ' -f2- | 
    tail -n "${CDHISTSIZE:-30}"
}

if (( "${#CDHIST[@]}" == 0 )); then
  while read -r; do
    case "${REPLY}" in
      ('') : ;;
      (*)  _cdhist append "${REPLY}" ;;
    esac
  done < <(_cdhist_skel)
fi

# Wrap 'cd' to automatically update GIT_BRANCH when necessary
# -- or -l : list the contents of the CDHIST stack
# up [n]   : go 'up' n directories e.g. 'cd ../../../' = 'cd up 3'
# -[n]     : go to the nth element of the CDHIST stack
cd() {
  local arg cdhist_result
  case "${1}" in
    (-)       command cd - || return 1 ;;
    (--|-l)   _cdhist list && return 0 ;;
    (-[0-9]*) command cd "$(_cdhist select "${1}")" || return 1 ;;
    (-f|--fzf|select)
      if ! command -v fzf >/dev/null 2>&1; then
        printf -- '%s\n' "'fzf' is required, but was not found in PATH" >&2
        return 1
      fi
      cdhist_result=$(printf -- '%s\n' "${CDHIST[@]}" | fzf -e --height 40% --border)
      if [[ -n "${cdhist_result}" ]]; then
        command cd "${cdhist_result}" || return 1
      fi
    ;;
    (up)
      shift 1
      case "${1}" in
        (*[!0-9]*) return 1 ;;
        ("")       command cd || return 1 ;;
        (1)        command cd .. || return 1 ;;
        (*)        command cd "$(eval "printf -- '../'%.0s {1..$1}")" || return 1 ;;
      esac
    ;;
    (-L|-P)
      arg="${1}"
      shift 1
      if (( "${#}" == 2 )); then
        command cd "${arg}" "${PWD/$1/$2}" || return 1
      else
        command cd "${arg}" "${@}" || return 1
      fi
    ;;
    (*)
      if (( "${#}" == 2 )); then
        command cd "${PWD/$1/$2}" || return 1
      else
        command cd "${@}" || return 1
      fi
    ;;
  esac
  # If CDPATH is set, we usually get PWD,
  # so to deduplicate we check that CDPATH is 0-length
  (( ${#CDPATH} == 0 )) && printf -- '%s\n' "${PWD:-$(pwd)}" >&2
  _set_git_branch_var
  _cdhist append "${PWD}"
}

# Print the given text in the center of the screen.
center() {
  local width
  width="${COLUMNS:-$(tput cols)}"
  while IFS= read -r; do
    # If, by luck, REPLY is the same as width, then just dump it
    (( ${#REPLY} == width )) && printf -- '%s\n' "${REPLY}" && continue

    # Handle lines of any length longer than width
    # this ensures that wrapped overflow is centered
    if (( ${#REPLY} > width )); then
      while read -r subreply; do
        (( ${#subreply} == width )) && printf -- '%s\n' "${subreply}" && continue
        printf -- '%*s\n' $(( (${#subreply} + width) / 2 )) "${subreply}"
      done < <(fold -w "${width}" <<< "${REPLY}")
      continue
    fi

    # Otherwise, print centered
    printf -- '%*s\n' $(( (${#REPLY} + width) / 2 )) "${REPLY}"
  done < "${1:-/dev/stdin}"
  [[ -n "${REPLY}" ]] && printf -- '%s\n' "${REPLY}"
}

# Check YAML syntax
checkyaml() {
  local textGreen textRed textRst
  textGreen=$(tput setaf 2)
  textRed=$(tput setaf 1)
  textRst=$(tput sgr0)

  # Check that $1 is defined...
  if [[ -z "${1}" ]]; then
    printf -- '%s\n' "Usage:  checkyaml file" ""
    printf -- '\t%s\n'  "Check the YAML syntax in FILE"
    return 1
  fi
  
  # ...and readable
  if [[ ! -r "${1}" ]]; then
    printf -- '%s\n' "${textRed}[ERROR]${textRst} checkyaml: '${1}' does not appear to exist or I can't read it."
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
    printf -- '%s\n' "${textGreen}[OK]${textRst} checkyaml: It seems the provided YAML syntax is ok."

  # Otherwise, print out an error message and dump the trace
  else
    printf -- '%s\n' "${textRed}[ERROR]${textRst} checkyaml: It seems there is an issue with the provided YAML syntax." ""
    python -c 'import yaml, sys; print yaml.load(sys.stdin)' < "${file:-/dev/stdin}"
  fi
}

# Try to enable clipboard functionality
# Terse version of https://raw.githubusercontent.com/rettier/c/master/c
if get_command pbcopy; then
  clipin() { pbcopy; }
  clipout() { pbpaste; }
elif get_command xclip; then
  clipin() { xclip -selection c; }
  clipout() { xclip -selection clipboard -o; }
elif get_command xsel ; then
  clipin() { xsel --clipboard --input; }
  clipout() { xsel --clipboard --output; }
else
  clipin() { printf -- '%s\n' "No clipboard capability found" >&2; }
  clipout() { printf -- '%s\n' "No clipboard capability found" >&2; }
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

# Function to convert a decimal to an ascii character
# See: https://www.ascii-code.com/
dec_to_char() {
  local int
  int="${1:?No integer supplied}"
  # Ensure that we have an integer
  case "${int}" in
    (*[!0-9]*) return 1 ;;
  esac
  
  # Ensure int is within the range 32-126
  # If it's less than 32, add 32 to bring it up into range
  (( int < 32 )) && int=$(( int + 32 ))
  
  # If it's greater than 126, divide until it's in range
  if (( int > 126 )); then
    until (( int <= 126 )); do
      int=$(( int / 2 ))
    done
  fi

  # Finally, print our character
  # shellcheck disable=SC2059
  printf "\\$(printf -- '%03o' "${int}")"
}

delete-branch() {
  local unwanted_branches current_branch mode
  current_branch="$(git symbolic-ref -q HEAD)"
  current_branch="${current_branch##refs/heads/}"
  current_branch="${current_branch:-HEAD}"

  case "${1}" in
    (--local)  shift 1; mode=local ;;
    (--remote) shift 1; mode=remote ;;
    (--both)   shift 1; mode=both ;;
    (*)        mode=local ;;
  esac

  case "${1}"  in
    ('')
      unwanted_branches=$(
        git branch |
          grep --invert-match '^\*' |
          cut -c 3- |
          fzf --multi --preview="git log {}"
      )
    ;;
    (*)  unwanted_branches="${*}" ;;
  esac

  case "${mode}" in
    (local)
      for branch in ${unwanted_branches}; do
        git branch --delete --force "${branch}"
      done
    ;;
    (remote)
      for branch in ${unwanted_branches}; do
        git push origin --delete "${branch}"
      done
    ;;
    (both)
      for branch in ${unwanted_branches}; do
        git branch --delete --force "${branch}"
        git push origin --delete "${branch}"
      done
    ;;
  esac
}

# Basic step-in function for dos2unix
# This simply removes dos line endings using 'sed'
if ! get_command dos2unix; then
  dos2unix() {
    if [[ "${1:0:1}" = '-' ]]; then
      printf -- '%s\n' "This is a simple step-in function, '${1}' isn't supported"
      return 1
    fi
    if [[ -w "${1}" ]]; then
      sed -ie 's/\r//g' "${1}"
    else
      sed -e 's/\r//g' -
    fi
  }
fi

# Function to extract common compressed file types
extract() {
  local xcmd rc fsobj

  (($#)) || return
  rc=0
  for fsobj; do
    xcmd=''

    if [[ ! -r ${fsobj} ]]; then
      printf -- '%s\n' "$0: file is unreadable: '${fsobj}'" >&2
      continue
    fi

    [[ -e ./"${fsobj#/}" ]] && fsobj="./${fsobj#/}"

    case ${fsobj} in
      (*.cbt|*.t@(gz|lz|xz|b@(2|z?(2))|a@(z|r?(.@(Z|bz?(2)|gz|lzma|xz)))))
        xcmd=(bsdtar xvf)
      ;;
      (*.7z*|*.arj|*.cab|*.chm|*.deb|*.dmg|*.iso|*.lzh|*.msi|*.rpm|*.udf|*.wim|*.xar)
        xcmd=(7z x)
      ;;
      (*.ace|*.cba)         xcmd=(unace x) ;;
      (*.cbr|*.rar)         xcmd=(unrar x) ;;
      (*.cbz|*.epub|*.zip)  xcmd=(unzip) ;;
      (*.cpio) cpio -id < "${fsobj}"; rc=$(( rc + "${?}" )); continue ;;
      (*.cso)
        ciso 0 "${fsobj}" "${fsobj}".iso; extract "${fsobj}".iso
        rm -rf "${fsobj:?}"; rc=$(( rc + "${?}" ))
        continue
      ;;
      (*.arc)   xcmd=(arc e);;
      (*.bz2)   xcmd=(bunzip2);;
      (*.exe)   xcmd=(cabextract);;
      (*.gz)    xcmd=(gunzip);;
      (*.lzma)  xcmd=(unlzma);;
      (*.xz)    xcmd=(unxz);;
      (*.Z|*.z) xcmd=(uncompress);;
      (*.zpaq)  xcmd=(zpaq x);;
      (*)
        printf -- '%s\n' "$0: unrecognized file extension: '${fsobj}'" >&2
        continue
      ;;
    esac

    command "${xcmd[@]}" "${fsobj}"
    rc=$(( rc + "${?}" ))
  done
  (( rc > 0 )) && return "${rc}"
  return 0
}

# Get a number of random integers using $RANDOM with debiased modulo
get-randint() {
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

# Go to the top of our git tree
gcd() {
  case "$(git rev-parse --show-toplevel 2>&1)" in
    (fatal*) return 1 ;;
    (*)      cd "$(git rev-parse --show-toplevel)/${1}" || return 1 ;;
  esac
}

# Let 'git' take the perf hit of setting GIT_BRANCH rather than PROMPT_COMMAND
# There's no one true way to get the current git branch, they all have pros/cons
# See e.g. https://stackoverflow.com/q/6245570
if get_command git; then
  git() {
    # If the args contain any mention of a master branch, we check for the newer 
    # 'main' nomenclature.  We take no other position than to suggest the correct command.
    if [[ "${*}" =~ 'master' ]]; then
      if command git branch 2>/dev/null | grep -qw "main"; then
        printf -- '%s\n' "This repo uses 'main' rather than 'master'." \
          "Try: 'git ${*/master/main}'" \
          "To override this warning, try: 'command git ${*}'" >&2
        return 1
      fi
    fi
    command git "${@}"
    GIT_BRANCH="$(command git branch 2>/dev/null| sed -n '/\* /s///p')"
    export GIT_BRANCH
  }
fi

# Small function to try and ensure setprompt etc behaves when escalating to root
# I don't want to override the default behaviour of 'sudo', hence the name
godmode() {
  case "${1}" in
    ('')
      # Testing for 'sudo -E' is hackish, let's just use this
      sudo bash --rcfile "${HOME}"/.bashrc
    ;;
    (*) sudo "$@" ;;
  esac
}

# Write a horizontal line of characters
hr() {
  # shellcheck disable=SC2183
  printf -- '%*s\n' "${1:-$COLUMNS}" | tr ' ' "${2:-#}"
}

# Function to indent text by n spaces (default: 2 spaces)
indent() {
  local identWidth
  identWidth="${1:-2}"
  identWidth=$(eval "printf -- '%.0s ' {1..${identWidth}}")
  sed "s/^/${identWidth}/" "${2:-/dev/stdin}"
}

# Get IP information using ipinfo's API
# Requires an env var: IPINFO_TOKEN, which I currently set in .workrc
ipinfo() {
  local target
  (( "${#IPINFO_TOKEN}" == 0 )) && {
    printf -- '%s\n' "IPINFO_TOKEN not found in the environment" >&2
    return 1
  }
  target="${1}"
  curl -s "https://ipinfo.io/${target}?token=${IPINFO_TOKEN}"
}

# Test if a given item is a function and emit a return code
is_function() {
  [[ $(type -t "${1:-grobblegobble}") = function ]]
}

# Are we within a directory that's tracked by git?
is_gitdir() {
  if [[ -e .git ]]; then
    return 0
  else
    git rev-parse --git-dir 2>&1 | grep -Eq '^.git|/.git'
  fi
}

# Test if a given value is an integer
is_integer() {
  printf -- '%d' "${1:?No integer given}" >/dev/null 2>&1
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

# Function to list the members of a group.  
# Replicates the absolute basic functionality of a real 'members' command
if ! get_command members; then
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
  # Fail early: We require sed
  if ! command -v sed >/dev/null 2>&1; then
    printf -- '%s\n' "[ERROR] printline: This function depends on 'sed' which was not found." >&2
    return 1
  fi

  # If $1 is empty, print a usage message
  # Otherwise, check that $1 is a number, if it isn't print an error message
  # If it is, blindly convert it to base10 to remove any leading zeroes
  case "${1}" in
    (''|-h|--help|--usage|help|usage)
      printf -- '%s\n' "Usage:  printline n [file]" ""
      printf -- '\t%s\n' "Print the Nth line of FILE." "" \
        "With no FILE or when FILE is -, read standard input instead."
      return 0
    ;;
    (*[!0-9]*)
      printf -- '%s\n' "[ERROR] printline: '${1}' does not appear to be a number." "" \
        "Run 'printline' with no arguments for usage." >&2
      return 1
    ;;
    (*) local lineNo="$((10#${1})){p;q;}" ;;
  esac

  # Next, we handle $2.  First, we check if it's a number, indicating a line range
  if (( "${2}" )) 2>/dev/null; then
    # Stack the numbers in lowest,highest order
    if (( "${2}" > "${1}" )); then
      lineNo="${1},$((10#${2}))p;$((10#${2}+1))q;"
    else
      lineNo="$((10#${2})),${1}p;$((${1}+1))q;"
    fi
    shift 1
  fi

  # Otherwise, we check if it's a readable file
  if [[ -n "${2}" ]]; then
    if [[ ! -r "${2}" ]]; then
      printf -- '%s\n' "[ERROR] printline: '$2' does not appear to exist or I can't read it." "" \
        "Run 'printline' with no arguments for usage." >&2
      return 1
    else
      local file="${2}"
    fi
  fi

  # Finally after all that testing and setup is done
  sed -ne "${lineNo}" -e "\$s/.*/[ERROR] printline: End of stream reached./" -e '$ w /dev/stderr' "${file:-/dev/stdin}"
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
    printf -- '%s\n' "Usage: quickserve [port(default: 8000)] [path(default: cwd)]"
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

# GUI-paginated man pages
# Inspired by the discussion here https://news.ycombinator.com/item?id=25304257
pman() {
  local mantext
  case "$(uname -s)" in
    (Darwin) man -t "${@}" | ps2pdf - - | open -g -f -a Preview ;;
    (Linux)
      mantext=$(mktemp)
      man -t "${@}" | ps2pdf - > "${mantext}"
      (
        evince "${mantext}"
        rm -f "${mantext}" 2>/dev/null
      )
    ;;
  esac
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
  ps auxf | awk -v proc="[${1:0:1}]${1:1}" '$0 ~ proc {print $2}'
}

# 'redo' the last command, optionally with search and replace
# Usage:
# redo <-- Invokes the last command
# redo foo bar <-- last command, replaces first instance of 'foo' with 'bar'
# redo -g foo bar <-- last command, replaces all instances of 'foo' with 'bar'
redo() {
  local last_cmd match_str replace_str
  # Ensure that 'redo' calls aren't put into our command history
  # This prevents 'redo' from 'redo'ing itself.  Which is a sin.  Repent etc.
  case "${HISTIGNORE}" in
    (*redo\**) : ;;
    (*)
      printf -- '%s\n' "Adding 'redo*' to HISTIGNORE.  Please make this permanent" >&2
      export HISTIGNORE="${HISTIGNORE}:redo*"
    ;;
  esac
  case "${1}" in
    ('')
      fc -s
    ;;
    (-h|--help)
      printf -- '%s\n' \
        "'redo' the last command, optionally with search and replace" \
        "Usage:" \
        "redo <-- Invokes the last command" \
        "redo foo bar <-- last command, replaces first instance of 'foo' with 'bar'" \
        "redo -g foo bar <-- last command, replaces all instances of 'foo' with 'bar'"
    ;;
    (-g|--global)
      shift 1
      match_str="${1:?Search parameter missing}"
      replace_str="${2:?Replacement parameter missing}"
      fc -s "${match_str}"="${replace_str}"
    ;;
    (*)
      last_cmd=$(fc -l -- -1  | cut -d ' ' -f2-)
      match_str="${1:?Search parameter missing}"
      replace_str="${2:?Replacement parameter missing}"
      ${last_cmd/$match_str/$replace_str}
    ;;
  esac
}

# A function to repeat an action any number of times
repeat() {
  local repeat_count
  repeat_count="${1}"
  # check that $1 is a digit, if not error out
  is_integer "${repeat_count}" || {
    printf -- '%s\n' "[ERROR]: '${1}' is not a number.  Usage: 'repeat n command'" >&2
    return 1
  }

  # shift so that the rest of the line is the command to execute
  shift 1

  # Run the command in a while loop repeatNum times
  for (( i=0; i<repeat_count; i++ )); do
    "${@}"
  done
}

# Create the file structure for an Ansible role
rolesetup() {
  if [[ -z "${1}" ]]; then
    printf -- '%s\n' "rolesetup - setup the file structure for an Ansible role." \
      "By default this creates into the current directory" \
      "and you can recursively copy the structure from there." "" \
      "Usage: rolesetup rolename" ""
    return 1
  fi

  if [[ ! -w . ]]; then
    printf -- '%s\n' "Unable to write to the current directory"
    return 1
  elif [[ -d "${1}" ]]; then
    printf -- '%s\n' "The directory '${1}' seems to already exist!"
    return 1
  else
    mkdir -p "${1}"/{defaults,files,handlers,meta,templates,tasks,vars}
    (
      cd "${1}" || return 1
      for dir in defaults files handlers meta templates tasks vars; do
        printf -- '%s\n' "---" > "${dir}/main.yml"
      done
    )
  fi
}

# Function for rounding floats
# Usage: round [precision] [float]
round() {
  printf "%.${2:-0}f" "${1:?No float given}"
}

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

# Silence ssh motd's etc using "-q"
# Adding "-o StrictHostKeyChecking=no" prevents key prompts
# and automatically adds them to ~/.ssh/known_hosts
ssh() {
  case "${1}" in
    (-h|--help)
      command ssh -h 2>&1 | grep -v "^unknown"
      printf -- '%s\n' "Overlay options:"
      printf -- '\t   %s\n' "dotfiles: syncs dotfiles to a remote host" \
        "nokeys: Forces password based authentication" \
        "raw: Runs ssh in its default, noisy state"
      return 0
    ;;
    (dotfiles)
      # Inspired by
      # https://github.com/cdown/sshrc/blob/master/sshrc
      # https://github.com/fsquillace/kyrat
      # https://github.com/BarbUk/dotfiles/blob/master/bin/ssh_connect
      remote_host="${2:?Remote Host not defined}"
      for dotfile in .bashrc .exrc .inputrc .pwords.dict .vimrc; do
        if ! [[ -r ~/"${dotfile}" ]]; then
          printf -- '%s\n' "Local copy of ${dotfile} missing" >&2
          continue
        fi
        local_sum=$(cksum ~/"${dotfile}" | awk '{print $1}')
        remote_sum=$(command ssh -q "${remote_host}" cksum "${dotfile}" 2>/dev/null | awk '{print $1}')
        if [[ "${local_sum}" = "${remote_sum}" ]]; then
          printf -- '%s\n' "${remote_host}:~/${dotfile} matches the local version"
        else
          printf -- '%s\n' "${remote_host}:~/${dotfile} appears outdated, updating..."
          scp ~/"${dotfile}" "${remote_host}:" || return 1
        fi
      done
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
  local fingerprint keyscanargs
  fingerprint=$(mktemp)

  trap 'rm -f "${fingerprint:?}" 2>/dev/null' RETURN

  # Test if the local host supports ed25519
  # Older versions of ssh don't have '-Q' so also likely won't have ed25519
  # If you wanted a more portable test: 'man ssh | grep ed25519' might be it
  ssh -Q key 2>/dev/null | grep -q ed25519 && keyscanargs=( -t "ed25519,rsa,ecdsa" )

  # If we have an arg "-a" or "--append", we add our findings to known_hosts
  case "${1}" in
    (-a|--append)
      shift 1
      ssh-keyscan "${keyscanargs[@]}" "${*}" > "${fingerprint}" 2> /dev/null
      # If the fingerprint file is empty, then quietly fail
      [[ -s "${fingerprint}" ]] || return 1
      cp "${HOME}"/.ssh/known_hosts{,."$(date +%Y%m%d)"}
      cat "${fingerprint}" ~/.ssh/known_hosts."$(date +%Y%m%d)" |
        sort | 
        uniq > "${HOME}"/.ssh/known_hosts
    ;;
    (''|-h|--help)
      printf -- '%s\n' "Usage: ssh-fingerprint (-a|--append) [list of hostnames]"
      return 1
    ;;
    (*)
      ssh-keyscan "${keyscanargs[@]}" "${*}" > "${fingerprint}" 2> /dev/null
      [[ -s "${fingerprint}" ]] || return 1
      ssh-keygen -l -f "${fingerprint}"
    ;;
  esac
}

# Add any number of integers together
# There is a historical 'sum' program, it has long been superseded by now
# by cksum, md5sum, sha256sum, digest and many similar others
sum() {
  local param sum
  case "${1}" in
    (-h|--help|--usage)
      {
        printf -- '%s\n' "Usage: sum x y [..z], or pipeline | sum"
        printf -- '\t%s\n' \
          "sum a sequence of integers, input by either positional parameters or STDIN"
      } >&2
      return 0
    ;;
  esac
  if [ ! -t 0 ]; then
    while read -r; do
      case "${REPLY}" in
        (*[!0-9]*) : ;;
        (*) sum=$(( sum + param )) ;;
      esac
    done < "${1:-/dev/stdin}"
    printf -- '%d\n' "${sum}"
    return 0
  fi
  for param in "${@}"; do
    case "${param}" in
      (*[!0-9]*) : ;;
      (*) sum=$(( sum + param )) ;;
    esac
  done
  printf -- '%d\n' "${sum}"
}

# Provide a very simple 'tac' step-in function
if ! get_command tac; then
  tac() {
    if get_command perl; then
      perl -e 'print reverse<>' < "${1:-/dev/stdin}"
    elif get_command awk; then
      awk '{line[NR]=$0} END {for (i=NR; i>=1; i--) print line[i]}' < "${1:-/dev/stdin}"
    elif get_command sed; then
      sed -e '1!G;h;$!d' < "${1:-/dev/stdin}"
    fi
  }
fi

# Check if 'timeout' is available, if not, enable a stop-gap function
if ! get_command timeout; then
  timeout() {
    local duration

    # $# should be at least 1, if not, print a usage message
    if (( $# == 0 )); then
      printf -- '%s\n' "Usage:  timeout DURATION COMMAND" ""
      printf -- '\t%s\n' \
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
        printf -- '%s\n' \
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
    if get_command perl; then
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
    elif get_command awk; then
      printf -- '%s ' "$*" | awk '{print tolower($0)}'
    elif get_command tr; then
      printf -- '%s ' "$*" | tr '[:upper:]' '[:lower:]'
    else
      printf -- '%s\n' "tolower - no available method found" >&2
      return 1
    fi
  else
    if (( BASH_VERSINFO >= 4 )); then
      while read -r; do
        printf -- '%s\n' "${REPLY,,}"
      done
      [[ -n "${REPLY}" ]] && printf -- '%s\n' "${REPLY,,}"
    elif get_command awk; then
      awk '{print tolower($0)}'
    elif get_command tr; then
      tr '[:upper:]' '[:lower:]'
    else
      printf -- '%s\n' "tolower - no available method found" >&2
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
    elif get_command awk; then
      printf -- '%s ' "$*" | awk '{print toupper($0)}'
    elif get_command tr; then
      printf -- '%s ' "$*" | tr '[:lower:]' '[:upper:]'
    else
      printf -- '%s\n' "toupper - no available method found" >&2
      return 1
    fi
  else
    if (( BASH_VERSINFO >= 4 )); then
      while read -r; do
        printf -- '%s\n' "${REPLY^^}"
      done
      [[ -n "${REPLY}" ]] && printf -- '%s\n' "${REPLY^^}"
    elif get_command awk; then
      awk '{print toupper($0)}'
    elif get_command tr; then
      tr '[:lower:]' '[:upper:]'
    else
      printf -- '%s\n' "toupper - no available method found" >&2
      return 1
    fi < "${1:-/dev/stdin}"
  fi
}

# Simple alternative for 'tree'
if ! get_command tree; then
  tree() {
    find "${1:-.}" -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'
  }
fi

# Format the output of 'du'.  Found on the internet, unknown origin.
if ! get_command treesize; then
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
  local outLn=""
  # If $1 is a readable file OR if $1 is blank, we process line by line
  # Because we assign a variable, leading and trailing whitespace is stripped
  if [[ -r "${1}" ]]||[[ -z "${1}" ]]; then
    while read -r outLn; do
      printf -- '%s\n' "${outLn}"
    done < "${1:-/dev/stdin}"
  # Otherwise, we process whatever input arg(s) have been supplied
  else
    local readLn="${*}"
    while true; do
      outLn="${readLn#[[:space:]]}"  # Strip whitespace to the left
      outLn="${outLn%[[:space:]]}"   # Strip whitespace to the right
      [[ "${outLn}" = "${readLn}" ]] && break
      readLn="${outLn}"
    done
    printf -- '%s\n' "${outLn}"
  fi
}

# Get local weather and present it nicely
weather() {
  # We require 'curl' so check for it
  if ! get_command curl; then
    printf -- '%s\n' "[ERROR] weather: This command requires 'curl', please install it."
    return 1
  fi

  # Handle our variables
  # If no arg is given, default to Wellington NZ
  local request curlArgs
  curlArgs="-H \"Accept-Language: ${LANG%_*}\" --compressed -m 10"
  case "${1}" in
    (-h|--help) request="wttr.in/:help" ;;
    (-m|--moon)   request="wttr.in/moon" ;;
    (-g|--graphs) shift 1; request="v2.wttr.in/${*:-Wellington}" ;;
    (*)         request="wttr.in/${*:-Wellington}" ;;
  esac

  # If the width is less than 125 cols, automatically switch to narrow mode
  (( "${COLUMNS:-$(tput cols)}" < 125 )) && request+='?n'
  
  # Finally, make the request
  curl "${curlArgs}" "${request}" 2>/dev/null ||
    printf -- '%s\n' "[ERROR] weather: Could not connect to weather service."
}

# Function to display a list of users and their memory and cpu usage
# Non-portable swap: for file in /proc/*/status ; do awk '/VmSwap|Name/{printf $2 " " $3}END{ print ""}' $file; done | sort -k 2 -n -r
what() {
  case "${1}" in
    (-h|--help)
      printf -- '%s\n' "what - list all users and their memory/cpu usage (think 'who' and 'what')" \
        "Usage: what [-c (sort by cpu usage) -m (sort by memory usage)]"
    ;;
    (-c)
      ps -eo pcpu,vsz,user | 
        tail -n +2 | 
        awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%\n", user, vsz[user]/1024, cpu[user]); }' | 
        sort -k7 -rn
    ;;
    (-m)
      ps -eo pcpu,vsz,user | 
        tail -n +2 | 
        awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%\n", user, vsz[user]/1024, cpu[user]); }' | 
        sort -k4 -rn
    ;;
    ('')
      ps -eo pcpu,vsz,user |
        tail -n +2 | 
        awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%\n", user, vsz[user]/1024, cpu[user]); }'
    ;;
  esac
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

yaml2json() {
  python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < "${1:-/dev/stdin}"
}

# Functionalise history | grep
# Named for this synonym trace: history -> past -> yore.
# 'past' kept triggering 'paste' in muscle memory :)
# TODO: Add '-u|--uniq' output
yore() {
  case "${#}" in
    (0)
      printf -- '%s\n' "Usage: yore [pattern] [-v|--invert-match|--not pattern]" >&2
    ;;
    (1)
      history | grep -E -- "${*}"
    ;;
    (*)
      local params index param filter_index filter_pattern search_pattern
      params=( "${@}" )
      index=0
      for param in "${params[@]}"; do
        case "${param}" in
          (-v|--invert-match|--not)
            filter_index=$(( index + 1 ))
            filter_pattern="${params[$filter_index]}"
            unset "params[$index]" "params[$filter_index]"
          ;;
          (*) (( ++index )) ;;
        esac
      done

      search_pattern="${params[*]}"
      # Filter first so that any grep colour settings work for the search
      history | grep -Ev -- "${filter_pattern}" | grep -E -- "${search_pattern}" 
    ;;
  esac
}

################################################################################
# genpasswd password generator
################################################################################
# Password generator function for when 'pwgen' or 'apg' aren't available
# Koremutake mode inspired by:
# https:#raw.githubusercontent.com/lpar/kpwgen/master/kpwgen.go
# http://shorl.com/koremutake.php
genpasswd() {
  export LC_CTYPE=C
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
      (h)  printf -- '%s\n' "" "genpasswd - a poor sysadmin's pwgen" \
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
      (\?)  printf -- '%s\n' "[ERROR] genpasswd: Invalid option: $OPTARG.  Try 'genpasswd -h' for usage." >&2
            return 1;;
      (:)  echo "[ERROR] genpasswd: Option '-$OPTARG' requires an argument, e.g. '-$OPTARG 5'." >&2
           return 1;;
    esac
  done

  # We need to check that the character length is more than 4 to protect against
  # infinite loops caused by the character checks.  i.e. 4 character checks on a 3 character password
  if (( pwdChars < 4 )); then
    printf -- '%s\n' "[ERROR] genpasswd: Password length must be greater than four characters." >&2
    return 1
  fi

  if [[ "${pwdKoremutake}" = "true" ]]; then
    for (( i=0; i<pwdNum; i++ )); do
      n=0
      for int in $(get-randint "${pwdChars:-7}" 1 $(( ${#pwdSyllables[@]} - 1 )) ); do
        tmpArray[n]=$(printf -- '%s\n' "${pwdSyllables[int]}")
        (( n++ ))
      done
      read -r t u v < <(get-randint 3 0 $(( ${#tmpArray[@]} - 1 )) | paste -s -)
      #pwdLower is effectively guaranteed, so we skip it and focus on the others
      if [[ "${pwdUpper}" = "true" ]]; then
        tmpArray[t]=$(capitalise "${tmpArray[t]}")
      fi
      if [[ "${pwdDigit}" = "true" ]]; then
        while (( u == t )); do
          u="$(get-randint 1 0 $(( ${#tmpArray[@]} - 1 )) )"
        done
        tmpArray[u]="$(get-randint 1 0 9)"
      fi
      if [[ "${pwdSpecial}" = "true" ]]; then
        while (( v == t )); do
          v="$(get-randint 1 0 $(( ${#tmpArray[@]} - 1 )) )"
        done
        randSpecial=$(get-randint 1 0 $(( ${#pwdSpecialChars[@]} - 1 )) )
        tmpArray[v]="${pwdSpecialChars[randSpecial]}"
      fi
      printf -- '%s\n' "${tmpArray[@]}" | paste -sd '\0' -
    done
  else
    for (( i=0; i<pwdNum; i++ )); do
      n=0
      while read -r; do
        tmpArray[n]="${REPLY}"
        (( n++ ))
      done < <(tr -dc "${pwdSet}" < /dev/urandom | tr -d ' ' | fold -w 1 | head -n "${pwdChars}")
      read -r t u v < <(get-randint 3 0 $(( ${#tmpArray[@]} - 1 )) | paste -s -)
      #pwdLower is effectively guaranteed, so we skip it and focus on the others
      if [[ "${pwdUpper}" = "true" ]]; then
        if ! printf -- '%s\n' "tmpArray[@]}" | grep "[A-Z]" >/dev/null 2>&1; then
          tmpArray[t]=$(capitalise "${tmpArray[t]}")
        fi
      fi
      if [[ "${pwdDigit}" = "true" ]]; then
        while (( u == t )); do
          u="$(get-randint 1 0 $(( ${#tmpArray[@]} - 1 )) )"
        done
        if ! printf -- '%s\n' "tmpArray[@]}" | grep "[0-9]" >/dev/null 2>&1; then
          tmpArray[u]="$(get-randint 1 0 9)"
        fi
      fi
      # Because special characters aren't sucked up from /dev/urandom,
      # we have no reason to test for them, just swap one in
      if [[ "${pwdSpecial}" = "true" ]]; then
        while (( v == t )); do
          v="$(get-randint 1 0 $(( ${#tmpArray[@]} - 1 )) )"
        done
        randSpecial=$(get-randint 1 0 $(( ${#pwdSpecialChars[@]} - 1 )) ) 
        tmpArray[v]="${pwdSpecialChars[randSpecial]}"
      fi
      printf -- '%s\n' "${tmpArray[@]}" | paste -sd '\0' -
    done
  fi
} 

################################################################################
# A separate password encryption tool, so that you can encrypt passwords of your own choice
cryptpasswd() {
  local inputPwd pwdSalt pwdKryptMode

  # If $1 is blank, print usage
  if [[ -z "${1}" ]]; then
    printf -- '%s\n' "" "cryptpasswd - a tool for hashing passwords" "" \
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
      printf -- '%s' "${inputPwd}" \
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
      if get_command python; then
        #python -c 'import crypt; print(crypt.crypt('${inputPwd}', crypt.mksalt(crypt.METHOD_SHA512)))'
        python -c "import crypt; print crypt.crypt('${inputPwd}', '\$${pwdKryptMode}\$${pwdSalt}')"
      elif get_command perl; then
        perl -e "print crypt('${inputPwd}','\$${pwdKryptMode}\$${pwdSalt}\$')"
      elif get_command openssl; then
        printf -- '%s\n' "This was handled by OpenSSL which is only MD5 capable." >&2
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
genphrase() {
  # Requires bash4 or newer and shuf
  # There is an older, more portable version of this available in my git history (pre 01/23)
  (( BASH_VERSINFO < 4 )) && {
    printf -- '%s\n' "genphrase(): bash 4 or newer required"
    return 1
  }
  command -v shuf >/dev/null 2>&1 || {
    printf -- '%s\n' "genphrase(): 'shuf' required but not found in PATH"
    return 1
  }

  # First, double check that the dictionary file exists.
  if [[ ! -f ~/.pwords.dict ]] ; then
    # Test if we can download our wordlist, otherwise use the standard 'words' file to generate something usable
    if ! wget -T 2 https://raw.githubusercontent.com/rawiriblundell/dotfiles/master/.pwords.dict -O ~/.pwords.dict &>/dev/null; then
      # Alternatively, we could just use grep -v "[[:punct:]]", but we err on the side of portability
      LC_COLLATE=C grep -Eh '^[A-Za-z].{3,9}$' /usr/{,share/}dict/words 2>/dev/null | grep -v "'" > ~/.pwords.dict
    fi
  fi

  # localise our vars for safety
  local OPTIND delimiter phrase_words phrase_num phrase_seed seed_word total_words

  # Default the vars
  delimiter='\0'
  phrase_words=4
  phrase_num=1
  phrase_seed="False"
  seed_word=

  while getopts ":d:hn:s:w:" Flags; do
    case "${Flags}" in
      (d) delimiter="${OPTARG}" ;;
      (h)
        printf -- '%s\n' "" "genphrase - a basic passphrase generator" \
          "" "Optional Arguments:" \
          "    -d Delimiter.  Note: Quote special chars. (Default: none)" \
          "    -h Help" \
          "    -n Number of passphrases to generate (Default: ${phrase_num})" \
          "    -s Seed your own word" \
          "    -w Number of random words to use (Default: ${phrase_words})" ""
        return 0
      ;;
      (n)  phrase_num="${OPTARG}" ;;
      (s)  phrase_seed="True"; seed_word="[${OPTARG}]" ;;
      (w)  phrase_words="${OPTARG}";;
      (:)
        printf -- "Option '%s' requires an argument. e.g. '%s 10'\n" "-${OPTARG}" "-${OPTARG}" >&2
        return 1
      ;;
      (*)
        printf -- "Unrecognised argument: '%s'\n" "-${OPTARG}.  Try 'genphrase -h' for usage." >&2
        return 1
      ;;
    esac
  done
  
  # Next test if a word is being seeded in, if so, make space for the seed word
  [[ "${phrase_seed}" = "True" ]] && (( phrase_words = phrase_words - 1 ))

  # Calculate the total number of words we might process
  total_words=$(( phrase_words * phrase_num ))
  
  # Now generate the passphrase(s)
  # Use 'shuf' to pull our complete number of random words from the dict
  # Use 'awk' to word wrap to '$phrase_words' per line
  # Then parse each line through this while loop
  while read -r; do
    # Convert the line to an array and add any seed word
    # This allows us to capitalise each word and randomise the seed location
    # shellcheck disable=SC2206 # We want REPLY to word-split
    lineArray=( ${seed_word} ${REPLY} )
    shuf -e "${lineArray[@]^}" | paste -sd "${delimiter}" -
  done < <(
    shuf -n "${total_words}" ~/.pwords.dict |
      awk -v w="${phrase_words}" 'ORS=NR%w?FS:RS'
    )
  return 0
}

################################################################################
# Standardise the Command Prompt
# NOTE for customisation: Any non-printing escape characters must be enclosed, 
# otherwise bash will miscount and get confused about where the prompt starts.  
# All sorts of line wrapping weirdness and prompt overwrites will then occur.  
# This is why all the escape codes have '\]' enclosing them.  Don't mess with that.

# Map out some block characters
# shellcheck disable=SC2034
block100="\xe2\x96\x88"  # u2588\0xe2 0x96 0x88 Solid Block 100%
block75="\xe2\x96\x93"   # u2593\0xe2 0x96 0x93 Dark shade 75%
block50="\xe2\x96\x92"   # u2592\0xe2 0x96 0x92 Half shade 50%
block25="\xe2\x96\x91"   # u2591\0xe2 0x96 0x91 Light shade 25%

# Put those block characters in ascending and descending triplets
blockAsc="$(printf -- '%b\n' "${block25}${block50}${block75}")"
blockDwn="$(printf -- '%b\n' "${block75}${block50}${block25}")"

# Source: https://gist.github.com/hypergig/ea6a60469ab4075b2310b56fa27bae55
# Define an array of color numbers for the colors that are hardest to see on
# either a black or white terminal background
BLOCKED_COLORS=(0 1 7 9 11 {15..18} {154..161} {190..197} {226..235} {250..255})

# Define another array that is an inversion of the above
mapfile -t ALLOWED_COLORS < <(printf -- '%d\n' {0..255} "${BLOCKED_COLORS[@]}" | sort -n | uniq -u)

# A function to generate a random color code using the above arrays
_select_random_color() {
  local color
  # Define our initial color code
  color=$(( RANDOM % 255 ))
  # Ensure that our color code is an allowed one.  If not, regenerate until it is.
  until printf -- '%d\n' "${ALLOWED_COLORS[@]}" | grep -xq "${color}"; do
    color=$(( RANDOM % 255 ))
  done
  # Emit our selected color number
  printf -- '%d\n' "${color}"
}

hrps1(){
  local color width
  # Figure out the width of the terminal window
  width="$(( "${COLUMNS:-$(tput cols)}" - 6 ))"
  # Define our initial color code
  color="$(_select_random_color)"
  tput setaf "${color}"               # Set our color
  printf -- '%s' "${blockAsc}"        # Print the ascending block sequence
  for (( i=1; i<=width; ++i )); do    # Fill the gap with hard blocks
    printf -- '%b' "${block100}"
  done
  printf -- '%s\n' "${blockDwn}"      # Print our descending block sequence
  tput sgr0                           # Unset our color
}

setprompt-help() {
cat << EOF
setprompt - configure state and colourisation of the bash prompt

    Usage: setprompt [-ghr|rand|safe|unset|[0-255]] [rand|[0-255]]

    Options:
      -g, --git
              Enable/disable git branch in the first text block
      -h, help, usage 
              Help, usage information
      -r, reset
              Restore prompt colours to defaults
      rand
              Select a random colour.  Can be used for 1st and 2nd colours
              e.g. 'setprompt rand rand'
              Note: This tries to be terminal safe; 
                    it excludes unreadable colours for both white
                    and black terminal backgrounds.
      safe
              Sets colours to white and black (i.e. black text on white)
      unset
              Sets the prompt to simply '$ '

    The first and second parameters will accept human readable colour codes.
    These are represented in short and full format e.g.
    For 'blue', you can enter 'bl', 'Bl', 'blue' or 'Blue'."
    This applies for:
    Black, Red, Green, Yellow, Blue, Magenta, Cyan, White and Orange.
    ANSI Numerical codes (0-255) can also be supplied"
    e.g. 'setprompt 143 76
    Note: This is not terminal safe, you can select unreadable colours

    A terminal supporting 256 colours is assumed.
    If you find issues, run 'setprompt safe' or 'setprompt unset'.
EOF
  return 0
}

# If we want to define our colours with a dotfile, we load it here
# shellcheck disable=SC1090
[[ -f "${HOME}/.setpromptrc" ]] && . "${HOME}/.setpromptrc"

setprompt() {
  # Setup sane defaults for the following variables
  : "${PS1_BG_COLOR:=32}" # Blue
  : "${PS1_FG_COLOR:=15}" # White
  : "${PS1_CHAR:=$}"

  # Let's setup some default primary and secondary colours for root/sudo
  if (( EUID == 0 )); then
    PS1_BG_COLOR="1"  # Red
    PS1_FG_COLOR="15" # White
    PS1_CHAR='#'
  fi

  case "${1}" in
    (-g|--git)
      case "${PS1_GIT_MODE}" in
        (True)  PS1_GIT_MODE=False ;;
        (False) PS1_GIT_MODE=True ;;
        (''|*)  PS1_GIT_MODE=True ;;
      esac
      export PS1_GIT_MODE
    ;;
    (-h|help|usage)         setprompt-help; return 0 ;;
    (-r|reset)
      unset PS1_BG_COLOR PS1_FG_COLOR
      #TODO: Validate that this dotfile isn't full of random garbage
      if [[ -r "${HOME}/.setpromptrc" ]]; then
        # shellcheck source=/dev/null
        . "${HOME}/.setpromptrc"
      fi
      : "${PS1_BG_COLOR:=32}" # Blue
      : "${PS1_FG_COLOR:=15}" # White
    ;;
    (b|B|black|Black)       PS1_BG_COLOR="0" ;;
    (r|R|red|Red)           PS1_BG_COLOR="1" ;;
    (g|G|green|Green)       PS1_BG_COLOR="2" ;;
    (y|Y|yellow|Yellow)     PS1_BG_COLOR="3" ;;
    (bl|Bl|blue|Blue)       PS1_BG_COLOR="32" ;;
    (m|M|magenta|Magenta)   PS1_BG_COLOR="164" ;;
    (c|C|cyan|Cyan)         PS1_BG_COLOR="50" ;;
    (w|W|white|White)       PS1_BG_COLOR="15" ;;
    (o|O|orange|Orange)     PS1_BG_COLOR="208" ;;
    (rand)
      PS1_BG_COLOR="$(_select_random_color)"
    ;;
    (safe)
      PS1_BG_COLOR="15" # White
      PS1_FG_COLOR="0"  # Black
    ;;
    (*[0-9]*)
      # Strip any non-digit chars and make sure it's less than 255
      # If not, print the help and fail out
      (( "${1//[^0-9]/}" > 255 )) && { setprompt-help; return 1; }
      PS1_BG_COLOR="${1//[^0-9]/}"
    ;;
    (unset)
      PS1='$ '
      export PS1
      return 0
    ;;
    (-|_)                   : #no-op ;;
  esac

  case "${2}" in
    (b|B|black|Black)       PS1_FG_COLOR="0" ;;
    (r|R|red|Red)           PS1_FG_COLOR="1" ;;
    (g|G|green|Green)       PS1_FG_COLOR="2" ;;
    (y|Y|yellow|Yellow)     PS1_FG_COLOR="3" ;;
    (bl|Bl|blue|Blue)       PS1_FG_COLOR="32" ;;
    (m|M|magenta|Magenta)   PS1_FG_COLOR="164" ;;
    (c|C|cyan|Cyan)         PS1_FG_COLOR="50" ;;
    (w|W|white|White)       PS1_FG_COLOR="15" ;;
    (o|O|orange|Orange)     PS1_FG_COLOR="208" ;;
    (rand)
      PS1_FG_COLOR="$(_select_random_color)"
    ;;
    (*[0-9]*)
      (( "${2//[^0-9]/}" > 255 )) && { setprompt-help; return 1; }
      PS1_FG_COLOR="${2//[^0-9]/}"
    ;;
    (-|_)                   : #no-op ;;
  esac

  #TODO: Simplify
  case "${PS1_GIT_MODE}" in
    (True)
      if is_gitdir; then
        if [[ -z "${GIT_BRANCH}" ]]; then
          if is_gitdir; then
            GIT_BRANCH="$(git branch 2>/dev/null| sed -n '/\* /s///p')"
          fi
        fi
        PS1_TEXT="[GIT:${GIT_BRANCH:-UNKNOWN}]"
      else
        PS1_TEXT="[GIT:Unrecognised]"
      fi
    ;;
    (*)
      unset PS1_TEXT
    ;;
  esac
  export PS1_TEXT

  # Typically a SHLVL of 2 and the existence of $AWS_VAULT means we're interacting with AWS
  # If so, set the colors to black on orange.  Standard AWS colours.
  # Also add $AWS_VAULT so that we know which AWS account we're in.
  if (( SHLVL > 1 )) && (( "${#AWS_VAULT}" > 0 )); then
    PS1_BG_COLOR="208" # Orange
    PS1_FG_COLOR="0"   # Black
    PS1_TEXT="[AWS:${AWS_VAULT}]"
    export PS1_TEXT
  fi

  # Build our PS1 variable
  PS1="\[\e[48;5;${PS1_BG_COLOR}m\]"
  PS1+="\[\e[38;5;${PS1_FG_COLOR}m\]"
  PS1+="[\$(date +%y%m%d/%H:%M)]\${PS1_TEXT}[${PWD}]"
  # Approximate the length of the text that will appear in the coloured block
  # If PS1_TEXT length is greater than 0, then we add:
  # date length + PS1_TEXT length + PWD length + 4 chars for extra brackets
  if (( ${#PS1_TEXT} > 0 )); then
    PS1_TEXTLEN=$(( 12 + ${#PS1_TEXT} + ${#PWD} + 4 ))
  # Otherwise, we add:
  # date length + PWD length + 4 chars for extra brackets
  else
    PS1_TEXTLEN=$(( 12 + ${#PWD} + 4 ))
  fi
  # Figure out how much padding to put in based on the terminal window
  PS1_PADDING="$(( "${COLUMNS:-$(tput cols)}" - PS1_TEXTLEN - 3 ))"
  PS1+=$(printf -- '%*s' "${PS1_PADDING:-10}" "")
  PS1+="\[\e[0m\]"
  PS1+="\[\e[38;5;${PS1_BG_COLOR}m\]"
  PS1+="${blockDwn}"
  PS1+="\[\e[0m\]"
  PS1+="\n"
  PS1+="${PS1_CHAR} "

  export PS1
  
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
