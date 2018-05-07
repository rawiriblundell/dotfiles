################################################################################
# .bashrc
# This file is read for interactive shells
# and .bash_profile is read for login shells

# Mostly, aliases and functions go into .bashrc 
# and environment variables and startup programs go into .bash_profile

# Unless there is a specific need, it's simpler to put most things into .bashrc
# And reference it into .bash_profile
################################################################################

# Source global definitions
if [[ -f /etc/bashrc ]]; then
  # shellcheck disable=SC1091
  . /etc/bashrc
fi

# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

# Aliases
# Some people use a different file for aliases
if [[ -f "${HOME}/.bash_aliases" ]]; then
  # shellcheck source=/dev/null
  . "${HOME}/.bash_aliases"
fi

# Functions
# Some people use a different file for functions
if [[ -f "${HOME}/.bash_functions" ]]; then
  # shellcheck source=/dev/null
  . "${HOME}/.bash_functions"
fi

# Set umask for new files
umask 027

################################################################################
# Open an array of potential PATH members, including Solaris bin/sbin paths
pathArray=(
  /usr/gnu/bin /usr/xpg6/bin /usr/xpg4/bin /usr/kerberos/bin /usr/kerberos/sbin \
  /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /opt/csw/bin \
  /opt/csw/sbin /opt/sfw/bin /opt/sfw/sbin /usr/sfw/bin /usr/sfw/sbin \
  /usr/games /usr/local/games /snap/bin "$HOME"/bin
)

# Iterate through the array and build the newPath variable using found paths
newPath=
for dir in "${pathArray[@]}"; do
  if [[ -d "${dir}" ]]; then
    newPath="${newPath}:${dir}"
  fi
done

# Now assign our freshly built newPath variable, removing any leading colon
PATH="${newPath#:}"

# Finally, export the PATH
export PATH

# A portable alternative to command -v/which/type
pathfind() {
  OLDIFS="$IFS"
  IFS=:
  for prog in $PATH; do
    if [[ -x "$prog/$*" ]]; then
      printf '%s\n' "$prog/$*"
      IFS="$OLDIFS"
      return 0
    fi
  done
  IFS="$OLDIFS"
  return 1
}

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
# Check the window size after each command and, if necessary,
# Update the values of LINES and COLUMNS.
# This attempts to correct line-wrapping-over-prompt issues when a window is resized
shopt -s checkwinsize

# Set the bash history timestamp format
export HISTTIMEFORMAT="%F,%T "

# don't put duplicate lines in the history. See bash(1) for more options
# and ignore commands that start with a space
HISTCONTROL=ignoredups:ignorespace
 
# append to the history file instead of overwriting it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=5000
HISTFILESIZE=5000

# Disable ctrl+s (XOFF) in PuTTY
stty ixany
stty ixoff -ixon

# Enable extended globbing
shopt -s extglob

################################################################################
# Programmable Completion (Tab Completion)

# Enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [[ -f /usr/share/bash-completion/bash_completion ]]; then
    # shellcheck disable=SC1091
    . /usr/share/bash-completion/bash_completion
  elif [[ -f /etc/bash_completion ]]; then
    # shellcheck disable=SC1091
    . /etc/bash_completion
  fi
fi

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
  # Call solresize() whenever a window is resized
  trap solresize SIGWINCH
  
elif [[ "$(uname)" = "Linux" ]]; then
  # Enable wide diff, handy for side-by-side i.e. diff -y or sdiff
  # Linux only, as -W/-w options aren't available in non-GNU
  alias diff='diff -W $(( $(tput cols) - 2 ))'
  alias sdiff='sdiff -w $(( $(tput cols) - 2 ))'
 
  # Correct backspace behaviour for some troublesome Linux servers that don't abide by .inputrc
  if tty --quiet; then
    stty erase '^?'
  fi
  
# I haven't used HP-UX in a while, but just to be sure
# we fix the backspace quirk for xterm
elif [[ "$(uname -s)" = "HP-UX" ]] && [[ "$TERM" = "xterm" ]]; then
  stty intr ^c
  stty erase ^?
fi

################################################################################
# Aliases

# If .curl-format exists, AND 'curl' is available, enable curl-trace alias
# See: https://github.com/wickett/curl-trace
if [[ -f ~/.curl-format ]] && command -v curl &>/dev/null; then
  alias curl-trace='curl -w "@/${HOME}/.curl-format" -o /dev/null -s'
fi

# Enable color support of ls and also add handy aliases
if [[ -x /usr/bin/dircolors ]]; then
  if [[ -r ~/.dircolors ]]; then
    eval "$(dircolors -b ~/.dircolors)"
  else
    eval "$(dircolors -b)"
  fi
fi

# It looks like blindly asserting the following upsets certain 
# Solaris versions of *grep.  So we throw in an extra check
if echo "test" | grep --color=auto test &>/dev/null; then
  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
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

if command -v vim &>/dev/null; then
  alias vi='vim'
fi

# Generated using https://dom111.github.io/grep-colors
GREP_COLORS='sl=49;39:cx=49;39:mt=49;31;1:fn=49;32:ln=49;33:bn=49;33:se=1;36'

# Generated by hand, referencing http://linux-sxs.org/housekeeping/lscolors.html
LS_COLORS='di=1;32:fi=0:ln=1;33;40:pi=1;33;40:so=1;33;40:bd=1;33;40:cd=1;33;40:or=5;33:mi=0:ex=1;31:*.rpm=1;31'

export GREP_COLORS LS_COLORS

################################################################################
# Functions

# Because you never know what crazy systems are out there
if ! command -v apropos >/dev/null 2>&1; then
  apropos() { man -k "$*"; }
fi

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
  if [[ "$1" = "-h" ]]; then
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
# See also n2c() for the opposite behaviour
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
  if [[ -t 0 ]] && [[ -z $1 ]]; then
    printf '%s\n' "Usage:  capitalise string" ""
    printf '\t%s\n' "Capitalises the first character of STRING and/or its elements."
    return 0
  # Disallow both piping in strings and declaring strings
  elif [[ ! -t 0 ]] && [[ ! -z $1 ]]; then
    printf '%s\n' "[ERROR] capitalise: Please select either piping in or declaring a string to capitalise, not both."
    return 1
  fi

  # If parameter is a file, or stdin is used, action that first
  # shellcheck disable=SC2119
  if [[ -r $1 ]]||[[ ! -t 0 ]]; then
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
      # If we're using bash4, stop mucking about
      if (( BASH_VERSINFO == 4 )); then
        #read -r -a inLine <<< "${REPLY}" # upsets Solaris grr
        for inString in ${REPLY}; do
          printf '%s ' "${inString^}" | trim
        done
      # Otherwise, take the more exhaustive approach
      else
        # Split each line element for processing
        for inString in ${REPLY}; do
          # If inString is an integer, skip to the next element
          isinteger "${inString}" && continue
          # Split off the first character and capitalise it
          inWord=$(echo "${inString:0:1}" | toupper)
          # Print out the uppercase var and the rest of the element
          outWord="${inWord}${inString:1}"
          # Pad the output so that multiple elements are spaced out
          printf "%s " "${outWord}"
        # We use to trim to remove any trailing whitespace
        done | trim
      fi
    done < "${1:-/dev/stdin}"

  # Otherwise, if a parameter exists, then capitalise all given elements
  # Processing follows the same path as before.
  elif [[ -n "$*" ]]; then
    if (( BASH_VERSINFO == 4 )); then
      printf '%s ' "${@^}" | trim
    else
      for inString in "$@"; do
        inWord=$(echo "${inString:0:1}" | toupper)
        outWord="$inWord${inString:1}"
        printf "%s " "${outWord}"
      done | trim
    fi
  fi
  
  # Unset GLOBIGNORE, even though we've tried to limit it to this function
  local GLOBIGNORE=
}

# Print the given text in the center of the screen.
# From https://github.com/Haroenv/config/blob/master/.bash_profile
center() {
  width="${COLUMNS:-$(tput cols)}"
  if [[ -r "$1" ]]; then
    pr -o "$(( width/2/2 ))" -t < "$1"
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
  if [[ -z $1 ]]; then
    printf '%s\n' "Usage:  checkyaml file" ""
    printf '\t%s\n'  "Check the YAML syntax in FILE"
    return 1
  fi
  
  # ...and readable
  if [[ ! -r "$1" ]]; then
    printf '%s\n' "${textRed}[ERROR]${textRst} checkyaml: '$1' does not appear to exist or I can't read it."
    return 1
  else
    local file
    file="$1"
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

# Indent code by four spaces, useful for posting in markdown
codecat() {
  indent 4 "$1"
}

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

# Optional error handling function
# See: https://www.reddit.com/r/bash/comments/5kfbi7/best_practices_error_handling/
die() {
  tput setaf 1
  printf '%s\n' "$@" >&2
  tput sgr0
  return 1
}

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
 if [[ -z "$1" ]]; then
    # display usage if no parameters given
    printf '%s\n' "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
 else
    if [[ -f "$1" ]]; then
      local nameInLowerCase
      nameInLowerCase=$(tolower "$1")
      case "${nameInLowerCase}" in
        (*.tar.bz2)   tar xvjf ./"$1"    ;;
        (*.tar.gz)    tar xvzf ./"$1"    ;;
        (*.tar.xz)    tar xvJf ./"$1"    ;;
        (*.lzma)      unlzma ./"$1"      ;;
        (*.bz2)       bunzip2 ./"$1"     ;;
        (*.rar)       unrar x -ad ./"$1" ;;
        (*.gz)        gunzip ./"$1"      ;;
        (*.tar)       tar xvf ./"$1"     ;;
        (*.tbz2)      tar xvjf ./"$1"    ;;
        (*.tgz)       tar xvzf ./"$1"    ;;
        (*.zip)       unzip ./"$1"       ;;
        (*.Z)         uncompress ./"$1"  ;;
        (*.7z)        7z x ./"$1"        ;;
        (*.xz)        unxz ./"$1"        ;;
        (*.exe)       cabextract ./"$1"  ;;
        (*)           echo "extract: '$1' - unknown archive method" ;;
      esac
    else
      printf '%s\n' "'$1' - file does not exist"
    fi
  fi
}

# flocate function.  This gives a search function that blends find and locate
# Will obviously only work where locate lives, so Solaris will mostly be out of luck
# Usage: flocate searchterm1 searchterm2 searchterm[n]
# Source: http://solarum.com/v.php?l=1149LV99
flocate() {
  if ! command -v locate &>/dev/null; then
    printf '%s\n' "[ERROR]: 'flocate' depends on 'locate', which wasn't found."
    return 1
  fi
  if (( $# > 1 )); then
    display_divider=1
  else
    display_divider=0
  fi

  current_argument=0
  total_arguments=$#
  while (( current_argument < total_arguments )); do
    current_file=$1
    if (( display_divider == 1 )); then
      printf '%s\n' "----------------------------------------" \
      "Matches for ${current_file}" \
      "----------------------------------------"
    fi

    filename_re="^\\(.*/\\)*${current_file//./\\.}$"
    locate -r "${filename_re}"
    shift
    (( current_argument = current_argument + 1 ))
  done
}

# Because $SHELL is a bad thing to test against, we provide this function
# This won't work for 'fish', which needs 'ps -p %self'
# Good thing we don't care about 'fish'
getShell() {
  ps -o comm= -p $$
  #ps -p "$$" | tail -n 1 | awk '{print $NF}'
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
  printf '%*s\n' "${1:-$COLUMNS}" | tr ' ' "${2:-#}"
}

# Function to indent text by n spaces (default: 2 spaces)
indent() {
  local identWidth
  identWidth="${1:-2}"
  identWidth=$(eval "printf '%.0s ' {1..$identWidth}")
  sed "s/^/${identWidth}/" "${2:-/dev/stdin}"
}

# Test if a given value is an integer
isinteger() {
  if test "$1" -eq "$1" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Replicate 'let'.  Likely to not be needed in bash, mostly for my reference
if ! command -v let &>/dev/null; then
  let() {
    return "$((!($1)))"
  }
fi

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

# Trim whitespace from the left hand side of an input
# Requires: shopt -s extglob
# awk alternative (portability unknown/untested):
# awk '{ sub(/^[ \t]+/, ""); print }'
ltrim() {
  if [[ -r "$1" ]]||[[ -z "$1" ]]; then
    while read -r; do
      printf -- '%s\n' "${REPLY##+([[:space:]])}"
    done < "${1:-/dev/stdin}"
  else
    printf -- '%s\n' "${@##+([[:space:]])}"
  fi
}

# If 'mapfile' is not available, offer it as a step-in function
# Written as an attempt at http://wiki.bash-hackers.org/commands/builtin/mapfile?s[]=mapfile#to_do
#   "Create an implementation as a shell function that's portable between Ksh, Zsh, and Bash 
#    (and possibly other bourne-like shells with array support)."

# Potentially useful resources: 
# http://cfajohnson.com/shell/arrays/
# https://stackoverflow.com/a/32931403

# Known issue: No traps!  This means IFS might be left altered if 
# the function is cancelled or fails in some way

if ! command -v mapfile >/dev/null 2>&1; then
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
    if [[ -n "$1" ]]; then
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
if ! command -v members >/dev/null 2>&1; then
  members() {
    [[ "$(getent group "${1?No Group Supplied}" | cut -d ":" -f4-)" ]] \
      && getent group "$1" | cut -d ":" -f4-
  }
fi

# Convert multiple lines to comma separated format
# See also c2n() for the opposite behaviour
n2c() {
  paste -sd ',' "${1:--}"
}

# Backup a file with the extension '.old'
old() { 
  cp --reflink=auto "$1"{,.old} 2>/dev/null || cp "$1"{,.old}
}

# A function to print a specific line from a file
printline() {
  # If $1 is empty, print a usage message
  if [[ -z $1 ]]; then
    printf '%s\n' "Usage:  printline n [file]" ""
    printf '\t%s\n' "Print the Nth line of FILE." "" \
      "With no FILE or when FILE is -, read standard input instead."
    return 0
  fi

  # Check that $1 is a number, if it isn't print an error message
  # If it is, blindly convert it to base10 to remove any leading zeroes
  case $1 in
    (''|*[!0-9]*) printf '%s\n' "[ERROR] printline: '$1' does not appear to be a number." "" \
                    "Run 'printline' with no arguments for usage.";
                  return 1 ;;
    (*)           local lineNo="$((10#$1))" ;;
  esac

  # Next, if $2 is set, check that we can actually read it
  if [[ -n "$2" ]]; then
    if [[ ! -r "$2" ]]; then
      printf '%s\n' "[ERROR] printline: '$2' does not appear to exist or I can't read it." "" \
        "Run 'printline' with no arguments for usage."
      return 1
    else
      local file="$2"
    fi
  fi

  # Finally after all that testing is done, we throw in a cursory test for 'sed'
  if command -v sed &>/dev/null; then
    sed -ne "${lineNo}{p;q;}" -e "\$s/.*/[ERROR] printline: End of stream reached./" -e '$ w /dev/stderr' "${file:-/dev/stdin}"
  # Otherwise we print a message that 'sed' isn't available
  else
    printf '%s\n' "[ERROR] printline: This function depends on 'sed' which was not found."
    return 1
  fi
}

# Start an HTTP server from a directory, optionally specifying the port
quickserve() {
  local port="${1:-8000}"
  sleep 1 && open "http://localhost:${port}/" &
  # Set the default Content-Type to `text/plain` instead of `application/octet-stream`
  # And serve everything as UTF-8 (although not technically correct, this doesn.t break anything for binary files)
  python -m "SimpleHTTPServer" "$port"
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

# Check if 'rev' is available, if not, enable a stop-gap function
if ! command -v rev &>/dev/null; then
  rev() {
    # Check that stdin or $1 isn't empty
    if [[ -t 0 ]] && [[ -z $1 ]]; then
      printf '%s\n' "Usage:  rev string|file" ""
      printf '\t%s\n'  "Reverse the order of characters in STRING or FILE." "" \
        "With no STRING or FILE, read standard input instead." "" \
        "Note: This is a bash function to provide the basic functionality of the command 'rev'"
      return 0
    # Disallow both piping in strings and declaring strings
    elif [[ ! -t 0 ]] && [[ ! -z $1 ]]; then
      printf '%s\n' "[ERROR] rev: Please select either piping in or declaring a string to reverse, not both."
      return 1
    fi

    # If parameter is a file, or stdin in used, action that first
    if [[ -f $1 ]]||[[ ! -t 0 ]]; then
      while read -r; do
        len=${#REPLY}
        rev=
        for((i=len-1;i>=0;i--)); do
          rev="$rev${REPLY:$i:1}"
        done
        printf '%s\n' "${rev}"
      done < "${1:-/dev/stdin}"
    # Else, if parameter exists, action that
    elif [[ ! -z "$*" ]]; then
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
  case "$1" in
    (*[!0-9]*|'') printf '%s\n' "[ERROR]: '$1' is not a number.  Usage: 'repeat n command'"; return 1;;
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
  if [[ -z "$1" ]]; then
    printf '%s\n' "rolesetup - setup the file structure for an Ansible role." \
      "By default this creates into the current directory" \
      "and you can recursively copy the structure from there." "" \
      "Usage: rolesetup rolename" ""
    return 1
  fi

  if [[ ! -w . ]]; then
    printf '%s\n' "Unable to write to the current directory"
    return 1
  elif [[ -d "$1" ]]; then
    printf '%s\n' "The directory '$1' seems to already exist!"
    return 1
  else
    mkdir -p "$1"/{defaults,files,handlers,meta,templates,tasks,vars}
    printf '%s\n' "---" > "$1"/{defaults,files,handlers,meta,templates,tasks,vars}/main.yml
  fi
}

# Trim whitespace from the right hand side of an input
# Requires: shopt -s extglob
# awk alternative (portability unknown/untested):
# awk '{ sub(/[ \t]+$/, ""); print }'
rtrim() {
  if [[ -r "$1" ]]||[[ -z "$1" ]]; then
    while read -r; do
      printf -- '%s\n' "${REPLY%%+([[:space:]])}"
    done < "${1:-/dev/stdin}"
  else
    printf -- '%s\n' "${@%%+([[:space:]])}"
  fi
}

# Escape special characters in a string, named for a similar function in R
sanitize() {
  printf '%q\n' "$1"
}
alias sanitise='sanitize'

# Check if 'seq' is available, if not, provide a basic replacement function
if ! command -v seq &>/dev/null; then
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
    if [[ -z "$2" ]]; then
      eval "printf -- '%d\\n' {1..$1}"
    # Otherwise, we act accordingly depending on how many parameters we get
    # This runs with a default increment of 1/-1 for two parameters
    elif [[ -z "$3" ]]; then
      eval "printf -- '%d\\n' {$1..$2}"
    # and with three parameters we use the second as our increment
    elif [[ -n "$3" ]]; then
      # First we test if the bash version is 4, if so, use native increment
      if (( "${BASH_VERSINFO[0]}" = "4" )); then
        eval "printf -- '%d\\n' {$1..$3..$2}"
      # Otherwise, use the manual approach
      else
        first="$1"
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
  # shellcheck disable=SC2059,SC1117
  printf "\033]0;${HOSTNAME%%.*}:${PWD}\007"
  # This might also need to be expressed as
  #printf "\\033]2;${HOSTNAME}:${PWD}\\007\\003"
  # I possibly need to test and figure out a way to auto-switch between these two
}

# Check if 'shuf' is available, if not, provide basic shuffle functionality
# Check commit history for a range of alternative methods - ruby, perl, python etc
# Requires: randInt function
if ! command -v shuf &>/dev/null; then
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
    if [[ -r "$1" ]]; then
      # Size it up first and adjust nCount if necessary
      if [[ -n "${nCount}" ]] && (( $(wc -l < "$1") < nCount )); then
        nCount=$(wc -l < "$1")
      fi
      exec 6< "$1"
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

# Function to essentially sort out "Terminal Too Wide" issue in vi on Solaris
solresize() {
  if (( "${COLUMNS:-$(tput cols)}" > 160 )); then
    stty columns "${1:-160}"
  fi
}

# Silence ssh motd's etc using "-q"
# Adding "-o StrictHostKeyChecking=no" prevents key prompts
# and automatically adds them to ~/.ssh/known_hosts
ssh() {
  /usr/bin/ssh -o StrictHostKeyChecking=no -q "$@"
}

# Display the fingerprint for a host
ssh-fingerprint() {
  if [[ -z $1 ]]; then
    printf '%s\n' "Usage: ssh-fingerprint [hostname]"
    return 1
  fi

  fingerprint=$(mktemp)

  # Test if the local host supports ed25519
  # Older versions of ssh don't have '-Q' so also likely won't have ed25519
  # If you wanted a more portable test: 'man ssh | grep ed25519' might be it
  if ssh -Q key 2>/dev/null | grep -q ed25519; then
    ssh-keyscan -t ed25519,rsa,ecdsa "$1" > "${fingerprint}" 2> /dev/null
  else
    ssh-keyscan "$1" > "${fingerprint}" 2> /dev/null
  fi
  ssh-keygen -l -f "${fingerprint}"
  rm -f "${fingerprint}"
}

# Test if a string contains a substring
# Example: stringContains needle haystack
stringContains() { 
  case "$2" in 
    (*$1*)  return 0 ;; 
    (*)     return 1 ;; 
  esac
}

# Provide a very simple 'tac' step-in function
if ! command -v tac &>/dev/null; then
  tac() {
    if command -v perl &>/dev/null; then
      perl -e 'print reverse<>' < "${1:-/dev/stdin}"
    elif command -v awk &>/dev/null; then
      awk '{line[NR]=$0} END {for (i=NR; i>=1; i--) print line[i]}' < "${1:-/dev/stdin}"
    elif command -v sed &>/dev/null; then
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
  # We do another check for portability
  # (GNU sleep can handle fractional seconds, non-GNU cannot)
  if ! sleep "${sleepTime}" &>/dev/null; then
    printf '%s\n' "[INFO] throttle: That time increment is not supported, defaulting to 1s"
    sleepTime=1
  fi

  # Now we output line by line with a sleep in the middle
  while read -r; do
    printf '%s\n' "${REPLY}"
    sleep "${sleepTime}"
  done
}

# Check if 'timeout' is available, if not, enable a stop-gap function
if ! command -v timeout &>/dev/null; then
  timeout() {

    # $# should be at least 1, if not, print a usage message
    if (($# == 0 )); then
      printf '%s\n' "Usage:  timeout DURATION COMMAND" ""
      printf '\t%s\n' "Start COMMAND, and kill it if still running after DURATION." "" \
        "DURATION is an integer with an optional  suffix:  's'  for" \
        "seconds (the default), 'm' for minutes, 'h' for hours or 'd' for days." "" \
        "Note: This is a bash function to provide the basic functionality of the command 'timeout'"
      return 0
    fi
    
    # Check that $1 complies, if not error out, if so, set the duration variable
    case "$1" in
      (*[!0-9smhd]*|'') printf '%s\n' "[ERROR] timeout: '$1' is not valid.  Run 'timeout' for usage."; return 1;;
      (*)           local duration=$1;;
    esac
    # shift so that the rest of the line is the command to execute
    shift

    # Convert timeout period into seconds
    # If it contains 'm', then convert to minutes
    if echo "${duration}" | grep "m" &>/dev/null; then
      # Make the variable numeric only
      duration="${duration//[!0-9]/}" 
      duration=$(( duration * 60 ))
      
    # ...and 'h' is for hours...
    elif echo "${duration}" | grep "h" &>/dev/null; then
      duration="${duration//[!0-9]/}" 
      duration=$(( duration * 60 * 60 ))
      
    # ...and 'd' is for days...
    elif echo "${duration}" | grep "d" &>/dev/null; then
      duration="${duration//[!0-9]/}" 
      duration=$(( duration * 60 * 60 * 24 ))
      
    # Otherwise, sanitise the variable of any other non-numeric characters
    else
      duration="${duration//[!0-9]/}"
    fi

    # If 'perl' is available, it has a few pretty good one-line options
    # see: http://stackoverflow.com/questions/601543/command-line-command-to-auto-kill-a-command-after-a-certain-amount-of-time
    if command -v perl &>/dev/null; then
      perl -e '$s = shift; $SIG{ALRM} = sub { kill INT => $p; exit 77 }; exec(@ARGV) unless $p = fork; alarm $s; waitpid $p, 0; exit ($? >> 8)' "${duration}" "$@"
      #perl -MPOSIX -e '$SIG{ALRM} = sub { kill(SIGTERM, -$$); }; alarm shift; $exit = system @ARGV; exit(WIFEXITED($exit) ? WEXITSTATUS($exit) : WTERMSIG($exit));' "$@"

    # Otherwise we offer a shell based failover.
    # I tested a few, this one works nicely and is fairly simple
    # http://stackoverflow.com/questions/24412721/elegant-solution-to-implement-timeout-for-bash-commands-and-functions/24413646?noredirect=1#24413646
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
  if [[ -n "$1" ]] && [[ ! -r "$1" ]]; then
    if (( BASH_VERSINFO == 4 )); then
      printf -- '%s ' "${*,,}" | paste -sd '\0' -
    elif command -v awk >/dev/null 2>&1; then
      printf -- '%s ' "$*" | awk '{print tolower($0)}'
    elif command -v tr >/dev/null 2>&1; then
      printf -- '%s ' "$*" | tr '[:upper:]' '[:lower:]'
    else
      printf '%s\n' "tolower - no available method found" >&2
      return 1
    fi
  else
    if (( BASH_VERSINFO == 4 )); then
      while read -r; do
        printf '%s\n' "${REPLY,,}"
      done
      [[ -n "${REPLY}" ]] && printf '%s\n' "${REPLY,,}"
    elif command -v awk >/dev/null 2>&1; then
      awk '{print tolower($0)}'
    elif command -v tr >/dev/null 2>&1; then
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
  if [[ -n "$1" ]] && [[ ! -r "$1" ]]; then
    if (( BASH_VERSINFO == 4 )); then
      printf -- '%s ' "${*^^}" | paste -sd '\0' -
    elif command -v awk >/dev/null 2>&1; then
      printf -- '%s ' "$*" | awk '{print toupper($0)}'
    elif command -v tr >/dev/null 2>&1; then
      printf -- '%s ' "$*" | tr '[:lower:]' '[:upper:]'
    else
      printf '%s\n' "toupper - no available method found" >&2
      return 1
    fi
  else
    if (( BASH_VERSINFO == 4 )); then
      while read -r; do
        printf '%s\n' "${REPLY^^}"
      done
      [[ -n "${REPLY}" ]] && printf '%s\n' "${REPLY^^}"
    elif command -v awk >/dev/null 2>&1; then
      awk '{print toupper($0)}'
    elif command -v tr >/dev/null 2>&1; then
      tr '[:lower:]' '[:upper:]'
    else
      printf '%s\n' "toupper - no available method found" >&2
      return 1
    fi < "${1:-/dev/stdin}"
  fi
}

# Add -p option to 'touch' to combine 'mkdir -p' and 'touch'
# The trick here is that we use 'command' to launch 'touch',
# as it overrides the shell's lookup order.. essentially speaking.
touch() {
  # Check if '-p' is present.
  # For bash3+ you could use 'if [[ "$@" =~ -p ]];'
  if echo "$@" | grep "\\-p" >/dev/null 2>&1; then

    # Transfer everything to a local array
    local argArray=( "$@" )

    # We need to remove '-p' no matter where it is in the array
    # This means searching for it, unsetting it, and reindexing
    # Newer bash versions could use "${!argArray[@]}" style handling
    for (( index=0; index<"${#argArray[@]}"; index++ )); do
      if [[ "${argArray[index]}" = "-p" ]]; then
        unset -- argArray["${index}"]
        argArray=( "${argArray[@]}" )
      fi
    done

    # Next extract a list of directories to process
    local dirArray=( "$(printf '%s\n' "${argArray[@]}" | grep "/$")" )
    for file in $(printf '%s\n' "${argArray[@]}" | grep "/" | grep -v "/$"); do
      dirArray+=( "$(dirname "${file}")" )
    done

    # As before, we sanitise the array to prevent issues
    # In this case, 'mkdir -p "" '
    for (( index=0; index<"${#dirArray[@]}"; index++ )); do
      if [[ -z "${dirArray[index]}" ]]; then
        unset -- dirArray["${index}"]
        dirArray=( "${dirArray[@]}" )
      fi
    done   

    # Okay, first, let's deal with the directories
    if (( "${#dirArray[*]}" > 0 )); then
      mkdir -p "${dirArray[@]}"
    fi

    # Now we can just run 'touch' with the sanitised array
    command touch "${argArray[@]}"

  # If '-p' isn't present, just use 'touch' as normal
  else
    command touch "$@"
  fi
}

# A small function to trim whitespace either side of a (sub)string
# shellcheck disable=SC2120
trim() {
  if [[ -n "$1" ]]; then
    printf -- '%s\n' "${@}" | awk '{$1=$1};1'
  else
    awk '{$1=$1};1'
  fi
}

# Provide normal, no-options ssh for error checking
unssh() {
  /usr/bin/ssh "$@"
}

# Provide 'up', so instead of e.g. 'cd ../../../' you simply type 'up 3'
up() {
  if (( "$#" < 1 )); then
    cd ..
  else
    cdstr=""
    for ((i=0; i<$1; i++)); do
      cdstr="../${cdstr}"
    done
    cd "${cdstr}" || exit
  fi
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

# Check if 'watch' is available, if not, enable a stop-gap function
if ! command -v watch &>/dev/null; then
  watch() {
    local OPTIND colWidth titleHead sleepTime dateNow

    while getopts ":hn:vt" optFlags; do
      case "${optFlags}" in
        (h)  printf '%s\n' "Usage:" " watch [-hntv] <command>" "" \
              "Options:" \
              "  -h, help.      Print a summary of the options" \
              "  -n, interval.  Seconds to wait between updates" \
              "  -v, version.   Print the version number" \
              "  -t, no title.  Turns off showing the header"
            return 0;;
        (n)  sleepTime="${OPTARG}";;
        (v)  printf '%s\n' "watch.  This is a bashrc function knockoff that steps in if the real watch is not found."
             return 0;;
        (t)  titleHead=false;;
        (\?)  printf '%s\n' "ERROR: This version of watch does not support '-$OPTARG'.  Try -h for usage or -v for version info." >&2
              return 1;;
        (:)  printf '%s\n' "ERROR: Option '-$OPTARG' requires an argument, e.g. '-$OPTARG 5'." >&2
             return 1;;
      esac
    done
    shift $(( OPTIND -1 ))

    # Set the default values for Title and Command
    sleepTime="${sleepTime:-2}"
    titleHead="${titleHead:-true}"

    if [[ -z "$*" ]]; then
      printf '%s\n' "ERROR: watch needs a command to watch.  Please try 'watch -h' for usage information."
      return 1
    fi

    while true; do
      clear
      if [[ "${titleHead}" = "true" ]]; then
        dateNow=$(date)
        (( colWidth = $(tput cols) - ${#dateNow} ))
        printf "%s%${colWidth}s" "Every ${sleepTime}s: $*" "${dateNow}"
        tput sgr0
        printf '%s\n' "" ""
      fi
      eval "$*"
      sleep "${sleepTime}"
    done
  }
fi

# Get local weather and present it nicely
weather() {
  # We require 'curl' so check for it
  if ! command -v curl &>/dev/null; then
    printf '%s\n' "[ERROR] weather: This command requires 'curl', please install it."
    return 1
  fi

  # If no arg is given, default to Wellington NZ
  curl -m 10 "http://wttr.in/${*:-Wellington}" 2>/dev/null || printf '%s\n' "[ERROR] weather: Could not connect to weather service."
}

# Function to display a list of users and their memory and cpu usage
# Non-portable swap: for file in /proc/*/status ; do awk '/VmSwap|Name/{printf $2 " " $3}END{ print ""}' $file; done | sort -k 2 -n -r
what() {
  # Start processing $1.  I initially tried coding this with getopts but it blew up
  if [[ "$1" = "-c" ]]; then
    ps -eo pcpu,vsz,user | tail -n +2 | awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%\n", user, vsz[user]/1024, cpu[user]); }' | sort -k7 -rn
  elif [[ "$1" = "-m" ]]; then
    ps -eo pcpu,vsz,user | tail -n +2 | awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%\n", user, vsz[user]/1024, cpu[user]); }' | sort -k4 -rn
  elif [[ -z "$1" ]]; then
    ps -eo pcpu,vsz,user | tail -n +2 | awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%\n", user, vsz[user]/1024, cpu[user]); }'
  else
    printf '%s\n' "what - list all users and their memory/cpu usage (think 'who' and 'what')" "Usage: what [-c (sort by cpu usage) -m (sort by memory usage)]"
  fi
}

# Function to get the owner of a file
whoowns() {
  # First we try GNU-style 'stat'
  if stat -c '%U' "$1" >/dev/null 2>&1; then
     stat -c '%U' "$1"
  # Next is BSD-style 'stat'
  elif stat -f '%Su' "$1" >/dev/null 2>&1; then
    stat -f '%Su' "$1"
  # Otherwise, we failover to 'ls', which is not usually desireable
  else
    # shellcheck disable=SC2012
    ls -ld "$1" | awk 'NR==1 {print $3}'
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
  # Declare OPTIND as local for safety
  local OPTIND

  # Default the vars
  Pwd="${1}"
  Salt=$(tr -dc '[:alnum:]' < /dev/urandom | tr '[:upper:]' '[:lower:]' | tr -d ' ' | fold -w 8 | head -n 1) 2> /dev/null
  PwdKryptMode="${2}"
  
  if [[ -z "${1}" ]]; then
    printf '%s\n' "" "cryptpasswd - a tool for hashing passwords" "" \
    "Usage: cryptpasswd [password to hash] [1|5|6]" \
    "    Crypt method can be set using '1' (MD5, default), '5' (SHA256) or '6' (SHA512)" \
    "    Any other arguments will default to MD5."
    return 0
  fi

  # We don't want to mess around with other options as it requires more error handling than I can be bothered with
  # If the crypt mode isn't 5 or 6, default it to 1, otherwise leave it be
  if [[ "${PwdKryptMode}" -ne 5 && "${PwdKryptMode}" -ne 6 ]]; then
    # Otherwise, default to MD5.
    PwdKryptMode=1
  fi

  # We check for python and if it's there, we use it
  if command -v python &>/dev/null; then
    PwdSalted=$(python -c "import crypt; print crypt.crypt('${Pwd}', '\$${PwdKryptMode}\$${Salt}')")
    # Alternative
    #python -c 'import crypt; print(crypt.crypt('${Pwd}', crypt.mksalt(crypt.METHOD_SHA512)))'
  # Next we failover to perl
  elif command -v perl &>/dev/null; then
    PwdSalted=$(perl -e "print crypt('${Pwd}','\$${PwdKryptMode}\$${Salt}\$')")
  # Otherwise, we failover to openssl
  # If command can't find it, we try to search some common Linux and Solaris paths for it
  elif ! command -v openssl &>/dev/null; then
    OpenSSL=$(command -v {,/usr/bin/,/usr/local/ssl/bin/,/opt/csw/bin/,/usr/sfw/bin/}openssl 2>/dev/null | head -n 1)
    # We can only generate an MD5 password using OpenSSL
    PwdSalted=$("${OpenSSL}" passwd -1 -salt "${Salt}" "${Pwd}")
    KryptMethod=OpenSSL
  fi

  # Now let's print out the result.  People can always awk/cut to get just the crypted password
  # This should probably be tee'd off to a dotfile so that they can get the original password too
  printf '%s\n' "Original: ${Pwd} Crypted: ${PwdSalted}"

  # In case OpenSSL is used, give an FYI before we exit out
  if [[ "${KryptMethod}" = "OpenSSL" ]]; then
    printf '%s\n' "Password encryption was handled by OpenSSL which is only MD5 capable."
  fi
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
      grep -Eh '^.{3,9}$' /usr/{,share/}dict/words 2>/dev/null | grep -Ev "é|'|-|\\.|/|&" > ~/.pwords.dict
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
  if command -v shuf &>/dev/null; then
    # If we're using bash4, then use mapfile for safety
    if (( BASH_VERSINFO == 4 )); then
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
      if (( BASH_VERSINFO == 4 )); then
        shuf -e "${lineArray[@]^}"
      else
        shuf -e "${lineArray[@]}" | capitalise
      fi | paste -sd '\0' -
    done
    return 0 # Prevent subsequent run of bash
  
  # Otherwise, we switch to bash.  This is the fastest way I've found to perform this
  else
    if ! command -v rand &>/dev/null; then
      printf '%s\n' "[ERROR] genphrase: This function requires the 'rand' external script, which was not found." \
        "You can get this script from https://github.com/rawiriblundell"
      return 1
    fi

    # We test for 'mapfile' which indicates bash4 or some step-in function
    if command -v mapfile &>/dev/null; then
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
          if (( BASH_VERSINFO == 4 )); then
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

# Password strength check function.  Can be fed a password most ways.
# TO-DO: add a verbose output switch
pwcheck () {
  # Read password in, if it's blank, prompt the user
  if [[ "${*}" = "" ]]; then
    read -resp $'Please enter the password/phrase you would like checked:\n' PwdIn
  else
    # Otherwise, whatever is fed in is the password to check
    PwdIn="${*}"
  fi

  # Check password, attempt with cracklib-check, failover to something a little more exhaustive
  if [[ -f /usr/sbin/cracklib-check ]]; then
    Method="cracklib-check"
    Result="$(echo "${PwdIn}" | /usr/sbin/cracklib-check)"
    Okay="$(awk -F': ' '{print $2}' <<<"${Result}")"
  else  
    # I think we have a common theme here.  Writing portable code sucks, but it keeps things interesting.
    
    Method="pwcheck"
    # Force 3 of the following complexity categories:  Uppercase, Lowercase, Numeric, Symbols, No spaces, No dicts
    # Start by giving a credential score to be subtracted from, then default the initial vars
    CredCount=4
    PWCheck="true"
    ResultChar="[OK]: Character count"
    ResultDigit="[OK]: Digit count"
    ResultUpper="[OK]: UPPERCASE count"
    ResultLower="[OK]: lowercase count"
    ResultPunct="[OK]: Special character count"
    ResultSpace="[OK]: No spaces found"
    ResultDict="[OK]: Doesn't seem to match any dictionary words"

    while [[ "${PWCheck}" = "true" ]]; do
      # Start cycling through each complexity requirement
      # We instantly fail for short passwords
      if [[ "${#PwdIn}" -lt "8" ]]; then
        printf '%s\n' "pwcheck: Password must have a minimum of 8 characters.  Further testing stopped.  (Score = 0)"
        return 1
      # And we instantly fail for passwords with spaces in them
      elif [[ "${PwdIn}" == *[[:blank:]]* ]]; then
        printf '%s\n' "pwcheck: Password cannot contain spaces.  Further testing stopped.  (Score = 0)"
        return 1
      fi
      # Check against the dictionary
      if grep -qh "${PwdIn}" /usr/{,share/}dict/words 2>/dev/null; then
        ResultDict="${PwdIn}: Password cannot contain a dictionary word.  (Score = 0)"
        CredCount=0 # Punish hard for dictionary words
      fi
      # Check for a digit
      if [[ ! "${PwdIn}" == *[[:digit:]]* ]]; then
        ResultDigit="[FAIL]: Password should contain at least one digit.  (Score -1)"
        ((CredCount = CredCount - 1))
      fi
      # Check for UPPERCASE
      if [[ ! "${PwdIn}" == *[[:upper:]]* ]]; then
        ResultUpper="[FAIL]: Password should contain at least one uppercase letter.  (Score -1)"
        ((CredCount = CredCount - 1))
      fi
      # Check for lowercase
      if [[ ! "${PwdIn}" == *[[:lower:]]* ]]; then
        ResultLower="[FAIL]: Password should contain at least one lowercase letter.  (Score -1)"
        ((CredCount = CredCount - 1))
      fi
      # Check for special characters
      if [[ ! "${PwdIn}" == *[[:punct:]]* ]]; then
        ResultPunct="[FAIL]: Password should contain at least one special character.  (Score -1)"
        ((CredCount = CredCount - 1))
      fi
      Result="$(printf '%s\n' "pwcheck: A score of 3 is required to pass testing, '${PwdIn}' scored ${CredCount}." \
        "${ResultChar}" "${ResultSpace}" "${ResultDict}" "${ResultDigit}" "${ResultUpper}" "${ResultLower}" "${ResultPunct}")"
      PWCheck="false" #Exit condition for the loop
    done

    # Now check password score, if it's less than three, then it fails
    # Here is where we force the three complexity catergories
    if [[ "${CredCount}" -lt "3" ]]; then
      # Rejected password, set variables appropriately
      Okay="NotOK"
    # Otherwise, it's a valid password
    else
      Okay="OK"
    fi
  fi

  # Output result
  if [[ "${Okay}" == "OK" ]]; then
    printf '%s\n' "pwcheck: The password/phrase passed my testing."
    return 0
  else
    printf '%s\n' "pwcheck: The check failed for password '${PwdIn}' using the ${Method} test." "${Result}" "Please try again."
    return 1
  fi
}

################################################################################
# Set the PROMPT_COMMAND
# If we've got bash v2 (e.g. Solaris 9), we cripple PROMPT_COMMAND.  Otherwise it will complain about 'history not found'
if (( BASH_VERSINFO[0] = 2 )) 2>/dev/null; then
  PROMPT_COMMAND="settitle; setprompt"
# Otherwise, for newer versions of bash (e.g. Solaris 10+), we treat it as per Linux
elif (( BASH_VERSINFO[0] > 2 )) 2>/dev/null; then
  # After each command, append to the history file and reread it
  # This attempts to keep history sync'd across multiple sessions
  PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r; settitle; setprompt"
fi
export PROMPT_COMMAND
################################################################################
# Standardise the Command Prompt
# NOTE for customisation: Any non-printing escape characters must be enclosed, 
# otherwise bash will miscount and get confused about where the prompt starts.  
# All sorts of line wrapping weirdness and prompt overwrites will then occur.  
# This is why all the escape codes have '\]' enclosing them.  Don't mess with that.
# The double backslash at the start also helps with this behaviour.
# 
# Bad:    \\[\e[0m\e[1;31m[\$(date +%y%m%d/%H:%M)]\[\e[0m
# Better:  \\[\e[0m\]\e[1;31m\][\$(date +%y%m%d/%H:%M)]\[\e[0m\]
#
# First, figure out $TERM, failing downwards
# 'xterm' does not support colour at all on Solaris, so is provided for safety
for termType in xterm-256color xterm-color xtermc dtterm xterm; do
  # Set TERM to the currently selected type
  export TERM="${termType}"
  # Test if 'tput' is upset, if so, move to the next option
  if tput colors 2>&1 | grep "unknown terminal" >/dev/null 2>&1; then
    continue
  # If 'tput' is not upset, then we've got a working type, so move on!
  else
    break
  fi
done
  
# Next, we map some colours:
case $(uname) in
  (FreeBSD)   
    ps1Red='\e[1;31m\]' # Bold Red
    ps1Grn='\e[0;32m\]' # Normal Green
    ps1Ylw='\e[1;33m\]' # Bold Yellow
    ps1Cyn='\e[1;36m\]' # Bold Cyan
    ps1Rst='\e[0m\]'
  ;;
  (*)
    case "${TERM}" in
      (xterm-256color)
        ps1Red="\[$(tput bold)\]\[$(tput setaf 9)\]"
        ps1Grn="\[$(tput setaf 10)\]"
        ps1Ylw="\[$(tput bold)\]\[$(tput setaf 11)\]"
        ps1Cyn="\[$(tput bold)\]\[$(tput setaf 14)\]"
        ps1Rst="\[$(tput sgr0)\]"
      ;;
      (*)
        ps1Red="\[$(tput bold)\]\[$(tput setaf 1)\]"
        ps1Grn="\[$(tput setaf 2)\]"
        ps1Ylw="\[$(tput bold)\]\[$(tput setaf 3)\]"
        ps1Cyn="\[$(tput bold)\]\[$(tput setaf 6)\]"
        ps1Rst="\[$(tput sgr0)\]"
      ;;
    esac
  ;;
esac

# Unicode u2588 \ UTF8 0xe2 0x96 0x88 - Solid Block
block100="\xe2\x96\x88"
block75="\xe2\x96\x93" # u2593\0xe2 0x96 0x93 Dark shade 75%
block50="\xe2\x96\x92" # u2592\0xe2 0x96 0x92 Half shade 50%
block25="\xe2\x96\x91" # u2591\0xe2 0x96 0x91 Light shade 25%

blockAsc="$(printf '%b\n' "${block25}${block50}${block75}")"
blockDwn="$(printf '%b\n' "${block75}${block50}${block25}")"

# Try to find out if we're authenticating locally or remotely
if grep "^${USER}:" /etc/passwd &>/dev/null; then
  auth="LCL"
else
  auth="AD"
fi

setprompt() {
  # Handle limited options for this function
  if [[ "$1" = "-h" ]]; then
    printf -- '%s\n' "Usage: setprompt [-h(elp)|-f(ull)|-m(inimal prompt)]"
    return 0
  elif [[ "$1" = "-f" ]]; then
    export PS1_UNSET=False
  elif [[ "$1" = "-m" ]]; then
    export PS1_UNSET=True
  fi

  # Let's setup our primary and secondary colours
  if [[ -w / ]]; then
    ps1Pri="${ps1Red}"
    ps1Sec="${ps1Red}"
    ps1Block="${blockAsc}"
  else
    ps1Pri="${ps1Red}"
    ps1Sec="${ps1Grn}"
    ps1Block="${blockDwn}"
  fi

  # Throw it all together, first we check if our unset flag is set
  # If so, we switch to a minimal prompt until 'setprompt -f' is run again
  if [[ "${PS1_UNSET}" = "True" ]]; then
    export PS1="${ps1Pri}${ps1Block}${ps1Rst}$ "
    return 0  # Stop further processing
  fi
  
  # Otherwise, it's business as usual.  We test how many columns we have.
  # If columns exceeds 80, use the long form, otherwise the short form
  if (( "${COLUMNS:-$(tput cols)}" > 80 )); then
    # shellcheck disable=SC1117
    export PS1="${ps1Pri}${ps1Block}[\$(date +%y%m%d/%H:%M)][${auth}]${ps1Sec}[\u@\h${ps1Rst} \W${ps1Sec}]${ps1Rst}$ "
  else
    # shellcheck disable=SC1117
    export PS1="${ps1Pri}[\u@\h${ps1Rst} \W${ps1Pri}]${ps1Rst}$ "
  fi
}

# Useful for debugging
export PS4='+$BASH_SOURCE:$LINENO:${FUNCNAME:-}: '
