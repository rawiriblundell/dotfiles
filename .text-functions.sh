# shellcheck shell=bash
# The MIT License (MIT)

# Copyright (c) 2019 -, Rawiri Blundell

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# TO-DO:
# * Check for $COLORTERM and fail out if/when possible
# * Something with this:
# ** https://cubicspot.blogspot.com/2019/05/designing-better-terminal-text-color.html
# References: 
# * https://gist.github.com/XVilka/8346728
# * https://stackoverflow.com/a/33206814

# Accept all of the foibles of 'echo'
text() {
  case "${1}" in
    (-e)
      case "${2}" in
        (-n)      shift 2; printf -- '%b' "${*}" ;;
        (*)       shift; printf -- '%b\n' "${*}" ;;
      esac
    ;;
    (-E)
      case "${2}" in
        (-n)      shift 2; printf -- '%s' "${*}" ;;
        (*)       shift; printf -- '%s\n' "${*}" ;;
      esac
    ;;
    (-n)
      case "${2}" in
        (-e)      shift 2; printf -- '%b' "${*}" ;;
        (-E)      shift 2; printf -- '%s' "${*}" ;;
        (*)       shift; printf -- '%s' "${*}" ;;
      esac
    ;;
    (-en|-ne)     shift; printf -- '%b' "${*}" ;;
    (-En|-nE)     shift; printf -- '%s' "${*}" ;;
    (*)           printf -- '%s\n' "${*}" ;;
  esac
}

# Remove leading number of lines.  Default: 1
text.behead() {
  awk -v head="${1:-1}" '{if (NR>head) {print}}'
}

# Convert text to slow blink
text.blink() {
  LC_CTYPE=C
  if [[ -r "${1}" ]]||[[ -z "${1}" ]]; then
    while read -r; do
      printf -- '\033[5m%s\033[0m\n' "${REPLY}"
    done < "${1:-/dev/stdin}"
  else
    printf -- '\033[5m%s\033[0m\n' "${*}"
  fi
}

# Convert text to bold
text.bold() {
  LC_CTYPE=C
  # If an arg is given and it's readable, then it's a file
  # Treat it line by line.  This caters for stdin as well
  if [[ -r "${1}" ]]||[[ -z "${1}" ]]; then
    while read -r; do
      printf -- '\033[1m%s\033[0m\n' "${REPLY}"
    done < "${1:-/dev/stdin}"
  # Otherwise, we process anything given as an arg
  else
    printf -- '\033[1m%s\033[0m\n' "${*}"
  fi
}

# Convert comma separated list to long format e.g. id user | tr "," "\n"
# See also text.n2c() and text.n2s() for the opposite behaviour
text.c2n() {
  while read -r; do 
    printf -- '%s\n' "${REPLY}" | tr "," "\\n"
  done < "${1:-/dev/stdin}"
}

# Print the given text in the center of the screen.
text.center() {
  local width
  width="${COLUMNS:-$(tput cols)}"
  while IFS= read -r; do
    (( ${#REPLY} >= width )) && printf -- '%s\n' "${REPLY}" && continue
    printf -- '%*s\n' $(( (${#REPLY} + width) / 2 )) "${REPLY}"
  done < "${1:-/dev/stdin}"
  [[ -n "${REPLY}" ]] && printf -- '%s\n' "${REPLY}"
}

# Convert text to faint
text.faint() {
  LC_CTYPE=C
  if [[ -r "${1}" ]]||[[ -z "${1}" ]]; then
    while read -r; do
      printf -- '\033[2m%s\033[0m\n' "${REPLY}"
    done < "${1:-/dev/stdin}"
  else
    printf -- '\033[2m%s\033[0m\n' "${*}"
  fi
}

# Write a horizontal line of characters
text.hr() {
  # shellcheck disable=SC2183
  printf -- '%*s\n' "${1:-$COLUMNS}" | tr ' ' "${2:-#}"
}

# Function to indent text by n spaces (default: 2 spaces)
text.indent() {
  local identWidth
  identWidth="${1:-2}"
  identWidth=$(eval "printf -- '%.0s ' {1..${identWidth}}")
  sed "s/^/${identWidth}/" "${2:-/dev/stdin}"
}

# Swap the foreground and background colours
text.invert() {
  LC_CTYPE=C
  if [[ -r "${1}" ]]||[[ -z "${1}" ]]; then
    while read -r; do
      printf -- '\033[7m%s\033[0m\n' "${REPLY}"
    done < "${1:-/dev/stdin}"
  else
    printf -- '\033[7m%s\033[0m\n' "${*}"
  fi
}

# Convert text to italic
text.italic() {
  LC_CTYPE=C
  if [[ -r "${1}" ]]||[[ -z "${1}" ]]; then
    while read -r; do
      printf -- '\033[3m%s\033[0m\n' "${REPLY}"
    done < "${1:-/dev/stdin}"
  else
    printf -- '\033[3m%s\033[0m\n' "${*}"
  fi
}

# Convert multiple lines to comma separated format
# See also text.c2n() for the opposite behaviour
text.n2c() { paste -sd ',' "${1:--}"; }

# Convert multiple lines to space separated format
text.n2s() { paste -sd ' ' "${1:--}"; }

# A function to print a specific line from a file
# TO-DO: Update it to handle globs e.g. 'printline 4 *'
text.printline() {
  # If $1 is empty, print a usage message
  if [[ -z "${1}" ]]; then
    printf -- '%s\n' "Usage:  text.printline n [file]" ""
    printf -- '\t%s\n' "Print the Nth line of FILE." "" \
      "With no FILE or when FILE is -, read standard input instead."
    return 0
  fi

  # Check that $1 is a number, if it isn't print an error message
  # If it is, blindly convert it to base10 to remove any leading zeroes
  case $1 in
    (''|*[!0-9]*) 
      printf -- '%s\n' "[ERROR] text.printline: '${1}' does not appear to be a number." "" \
      "Run 'printline' with no arguments for usage.";
      return 1
    ;;
    (*)
      local lineNo="$((10#$1))"
    ;;
  esac

  # Next, if $2 is set, check that we can actually read it
  if [[ -n "${2}" ]]; then
    if [[ ! -r "${2}" ]]; then
      printf -- '%s\n' "[ERROR] text.printline: '$2' does not appear to exist or I can't read it." "" \
        "Run 'printline' with no arguments for usage."
      return 1
    else
      local file="${2}"
    fi
  fi

  # Finally after all that testing is done, we throw in a cursory test for 'sed'
  if is_command sed; then
    sed -ne "${lineNo}{p;q;}" -e "\$s/.*/[ERROR] text.printline: End of stream reached./" -e '$ w /dev/stderr' "${file:-/dev/stdin}"
  # Otherwise we print a message that 'sed' isn't available
  else
    printf -- '%s\n' "[ERROR] text.printline: This function depends on 'sed' which was not found."
    return 1
  fi
}

# Strikethrough the text
text.strike() {
  LC_CTYPE=C
  if [[ -r "${1}" ]]||[[ -z "${1}" ]]; then
    while read -r; do
      printf -- '\033[9m%s\033[0m\n' "${REPLY}"
    done < "${1:-/dev/stdin}"
  else
    printf -- '\033[9m%s\033[0m\n' "${*}"
  fi
}

# Trim whitespace either side of text
text.trim() {
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

# Convert text to be underlined
text.underline() {
  LC_CTYPE=C
  if [[ -r "${1}" ]]||[[ -z "${1}" ]]; then
    while read -r; do
      printf -- '\033[4m%s\033[0m\n' "${REPLY}"
    done < "${1:-/dev/stdin}"
  else
    printf -- '\033[4m%s\033[0m\n' "${*}"
  fi
}

# Function to wrap an input to n words per line
text.wordwrap() {
  xargs -n "${1:-1}" < "${2:-/dev/stdin}"
}

################################################################################
# Colors / colours

# Change the foreground (i.e. text) colour
text.fg() {
  LC_CTYPE=C
  local fg_colour
  case "${1}" in
    (b|B|black|Black)        fg_colour='\033[38;5;0m';;
    (r|R|red|Red)            fg_colour='\033[1;31m';;
    (g|G|green|Green)        fg_colour='\033[0;32m';;
    (y|Y|yellow|Yellow)      fg_colour='\033[1;33m';;
    (bl|Bl|blue|Blue)        fg_colour='\033[38;5;32m';;
    (m|M|magenta|Magenta)    fg_colour='\033[1;35m';;
    (c|C|cyan|Cyan)          fg_colour='\033[1;36m';;
    (w|W|white|White|safe)   fg_colour='\033[1;37m';;
    (o|O|orange|Orange)      fg_colour='\033[38;5;208m';;
    ('_'|'-'|'null'|''|rand) fg_colour="\033[38;5;$((RANDOM%255))m";;
    (*[0-9]*)
      fg_colour="${1//[^0-9]/}"
      while (( fg_colour > 255 )); do
        fg_colour=$(( fg_colour / 2 ))
      done
      fg_colour="\033[38;5;${fg_colour}m"
    ;;
  esac
  shift
  if [[ -r "${1}" ]]||[[ -z "${1}" ]]; then
    while read -r; do
      printf -- "${fg_colour}%s\033[0m\n" "${REPLY}"
    done < "${1:-/dev/stdin}"
  else
    printf -- "${fg_colour}%s\033[0m\n" "${*}"
  fi
}

# Change the background colour
text.bg() {
  LC_CTYPE=C
  local bg_colour
  case "${1}" in
    (b|B|black|Black)        bg_colour='\033[48;5;0m';;
    (r|R|red|Red)            bg_colour='\033[0;41m';;
    (g|G|green|Green)        bg_colour='\033[0;42m';;
    (y|Y|yellow|Yellow)      bg_colour='\033[0;43m';;
    (bl|Bl|blue|Blue)        bg_colour='\033[48;5;32m';;
    (m|M|magenta|Magenta)    bg_colour='\033[0;45m';;
    (c|C|cyan|Cyan)          bg_colour='\033[0;46m';;
    (w|W|white|White|safe)   bg_colour='\033[0;47m';;
    (o|O|orange|Orange)      bg_colour='\033[48;5;208m';;
    ('_'|'-'|'null'|''|rand) bg_colour="\033[48;5;$((RANDOM%255))m";;
    (*[0-9]*)
      bg_colour="${1//[^0-9]/}"
      while (( bg_colour > 255 )); do
        bg_colour=$(( bg_colour / 2 ))
      done
      bg_colour="\033[48;5;${bg_colour}m"
    ;;
  esac
  shift
  if [[ -r "${1}" ]]||[[ -z "${1}" ]]; then
    while read -r; do
      printf -- "${bg_colour}%s\033[0m\n" "${REPLY}"
    done < "${1:-/dev/stdin}"
  else
    printf -- "${bg_colour}%s\033[0m\n" "${*}"
  fi
}

# Change the foreground colour (truecolor mode)
text.rgb.fg() {
  local fg_red fg_green fg_blue fg_colour
  case "${1}" in
    (*[0-9]*)
      fg_red="${1//[^0-9]/}"
      while (( fg_red > 255 )); do
        fg_red=$(( fg_red / 2 ))
      done
    ;;
    ('_'|'-'|'null'|''|*) fg_red=$((RANDOM%255))
  esac
  case "${2}" in
    (*[0-9]*)
      fg_green="${1//[^0-9]/}"
      while (( fg_red > 255 )); do
        fg_green=$(( fg_green / 2 ))
      done
    ;;
    ('_'|'-'|'null'|''|*) fg_green=$((RANDOM%255))
  esac
  case "${3}" in
    (*[0-9]*)
      fg_blue="${1//[^0-9]/}"
      while (( fg_blue > 255 )); do
        fg_blue=$(( fg_blue / 2 ))
      done
    ;;
    ('_'|'-'|'null'|''|*) fg_blue=$((RANDOM%255))
  esac
  shift 3
  fg_colour="\033[38;2;${fg_red};${fg_green};${fg_blue}m"
  if [[ -r "${1}" ]]||[[ -z "${1}" ]]; then
    while read -r; do
      printf -- "${fg_colour}%s\033[0m\n" "${REPLY}"
    done < "${1:-/dev/stdin}"
  else
    printf -- "${fg_colour}%s\033[0m\n" "${*}"
  fi
}

# Change the background colour (truecolor mode)
text.rgb.bg() {
  local bg_red bg_green bg_blue bg_colour
  case "${1}" in
    (*[0-9]*)
      bg_red="${1//[^0-9]/}"
      while (( bg_red > 255 )); do
        bg_red=$(( bg_red / 2 ))
      done
    ;;
    ('_'|'-'|'null'|''|*) bg_red=$((RANDOM%255))
  esac
  case "${2}" in
    (*[0-9]*)
      bg_green="${1//[^0-9]/}"
      while (( bg_red > 255 )); do
        bg_green=$(( bg_green / 2 ))
      done
    ;;
    ('_'|'-'|'null'|''|*) bg_green=$((RANDOM%255))
  esac
  case "${3}" in
    (*[0-9]*)
      bg_blue="${1//[^0-9]/}"
      while (( bg_blue > 255 )); do
        bg_blue=$(( bg_blue / 2 ))
      done
    ;;
    ('_'|'-'|'null'|''|*) bg_blue=$((RANDOM%255))
  esac
  shift 3
  bg_colour="\033[48;2;${bg_red};${bg_green};${bg_blue}m"
  if [[ -r "${1}" ]]||[[ -z "${1}" ]]; then
    while read -r; do
      printf -- "${bg_colour}%s\033[0m\n" "${REPLY}"
    done < "${1:-/dev/stdin}"
  else
    printf -- "${bg_colour}%s\033[0m\n" "${*}"
  fi
}

################################################################################
# Case transformations

# Setup a function for capitalising a single string
# This is used by the above capitalise() function
# The portable version depends on toupper() and trim()
if (( BASH_VERSINFO >= 4 )); then
  text.capitalise-string() {
    printf -- '%s\n' "${1^}"
  }
else
  text.capitalise-string() {
    # Split off the first character, uppercase it and trim
    # Next, print the string from the second character onwards
    printf -- '%s\n' "$(text.toupper "${1:0:1}" | text.trim)${1:1}"
  }
fi

# Capitalise words
# This is a bash-portable way to do this.
# To achieve with awk, use awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
# Known problem: leading whitespace is chomped.
text.capitalise() {
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
        test "${inString}" -eq "${inString}" 2>/dev/null && continue
        text.capitalise-string "${inString}"
      # We use to trim to remove any trailing whitespace
      done | paste -sd ' ' -
    done < "${1:-/dev/stdin}"

  # Otherwise, if a parameter exists, then capitalise all given elements
  # Processing follows the same path as before.
  elif [[ -n "$*" ]]; then
    for inString in "$@"; do
      text.capitalise-string "${inString}"
    done | paste -sd ' ' -
  fi
  
  # Unset GLOBIGNORE, even though we've tried to limit it to this function
  local GLOBIGNORE=
}

# Convert text to lowercase
# For a shell-native version, see:
# See https://gist.github.com/rawiriblundell/7b6914a11d3fdcdbd9aebc45fd38b4a1
# TO-DO: Maybe one day merge it in here?
# The chance of needing it (i.e. no 'awk' or 'tr') is virtually nonexistent...
text.tolower() {
  if [[ -n "${1}" ]] && [[ ! -r "${1}" ]]; then
    if (( BASH_VERSINFO >= 4 )); then
      printf -- '%s ' "${*,,}" | paste -sd '\0' -
    elif is_command awk; then
      printf -- '%s ' "$*" | awk '{print tolower($0)}'
    elif is_command tr; then
      printf -- '%s ' "$*" | tr '[:upper:]' '[:lower:]'
    else
      printf -- '%s\n' "text.tolower - no available method found" >&2
      return 1
    fi
  else
    if (( BASH_VERSINFO >= 4 )); then
      while read -r; do
        printf -- '%s\n' "${REPLY,,}"
      done
      [[ -n "${REPLY}" ]] && printf -- '%s\n' "${REPLY,,}"
    elif is_command awk; then
      awk '{print tolower($0)}'
    elif is_command tr; then
      tr '[:upper:]' '[:lower:]'
    else
      printf -- '%s\n' "text.tolower - no available method found" >&2
      return 1
    fi < "${1:-/dev/stdin}"
  fi
}

# Convert text to uppercase
text.toupper() {
  if [[ -n "${1}" ]] && [[ ! -r "${1}" ]]; then
    if (( BASH_VERSINFO >= 4 )); then
      printf -- '%s ' "${*^^}" | paste -sd '\0' -
    elif is_command awk; then
      printf -- '%s ' "$*" | awk '{print toupper($0)}'
    elif is_command tr; then
      printf -- '%s ' "$*" | tr '[:lower:]' '[:upper:]'
    else
      printf -- '%s\n' "text.toupper - no available method found" >&2
      return 1
    fi
  else
    if (( BASH_VERSINFO >= 4 )); then
      while read -r; do
        printf -- '%s\n' "${REPLY^^}"
      done
      [[ -n "${REPLY}" ]] && printf -- '%s\n' "${REPLY^^}"
    elif is_command awk; then
      awk '{print toupper($0)}'
    elif is_command tr; then
      tr '[:lower:]' '[:upper:]'
    else
      printf -- '%s\n' "text.toupper - no available method found" >&2
      return 1
    fi < "${1:-/dev/stdin}"
  fi
}

################################################################################
# Convenient aliases for the above functions

alias text.capitalize='text.capitalise'
alias text.centre='text.center'
alias text.color='text.fg'
alias text.colour='text.fg'
alias trim='text.trim'
alias tolower='text.tolower'
alias toupper='text.toupper'
