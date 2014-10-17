# .bashrc
# This file is read for interactive shells
# and .bash_profile is read for login shells

# Mostly, aliases and functions go into .bashrc 
# and environment variables and startup programs go into .bash_profile

# Unless there is a specific need, it's simpler to put most things into .bashrc
# And reference it into .bash_profile
#

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

# Aliases
# Some people use a different file for aliases
if [ -f "${HOME}/.bash_aliases" ]; then
	source "${HOME}/.bash_aliases"
fi

# Functions
# Some people use a different file for functions
if [ -f "${HOME}/.bash_functions" ]; then
	source "${HOME}/.bash_functions"
fi

# Set umask for new files
umask 027

# Silence ssh motd's etc using "-q"
# Adding "-o StrictHostKeyChecking=no" prevents key prompts
# and automatically adds them to ~/.ssh/known_hosts
ssh() {
/usr/bin/ssh -o StrictHostKeyChecking=no -q $*
}

# Provide normal, no-options ssh for error checking
unssh() {
/usr/bin/ssh $*
}

# Enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
	test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
	alias ls='ls --color=auto'
	#alias dir='dir --color=auto'
	#alias vdir='vdir --color=auto'
			 
	alias grep='grep --color=auto'
        alias fgrep='fgrep --color=auto'
	alias egrep='egrep --color=auto'
fi
			     
# Some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias lh='ls -lah'
alias l='ls -CF'

# Password generator function for when pwgen or apg aren't available
genpasswd() {
	# Declare OPTIND as local for safety
	local OPTIND

	# Default the vars
	PwdChars=10
	PwdNum=1
	PwdSet="[:alnum:]"
	PwdCols="false"
	PwdKrypt="false"

	while getopts ":Cc:n:hkSs" Flags; do
		case "${Flags}" in
			C)	PwdCols="true";;
			c)	PwdChars="${OPTARG}";;
			h)	printf "%s\n" "genpasswd - a poor sysadmin's pwgen" \
				"Optional arguments:" \
				"-C [attempt to output into columns (Default:off)]" \
				"-c [number of characters (Default:${PwdChars})]" \
                                "-h [help]" \
				"-k [krypt, generates a crypted/salted password for tools like usermod -p and chpasswd -e" \
				"    use of -C [columns] will be disallowed when this mode is enabled.  (Default:off)]" \
				"-n [number of passwords (Default:${PwdNum})]" \
				"-s [strong mode, seeds a limited amount of special characters into the mix (Default:off)]" \
				"-S [stronger mode, complete mix of characters (Default:off)]" \
				"Note: Broken Pipe errors, (older bash versions) can be ignored"
				return 0;;
			k)	PwdKrypt="true";;
                        n)      PwdNum="${OPTARG}";;
                                # Attempted to randomise special chars using 7 random chars from [:punct:] but reliably
                                # got "reverse collating sequence order" errors.  Seeded 9 special chars manually instead.
                        s)      PwdSet="[:alnum:]#$&+/<}^%";;
                        S)      PwdSet="[:graph:]";;
			\?)	echo "ERROR: Invalid option: $OPTARG.  Try 'genpasswd -h' for usage." >&2
				return 1;;
			
			:)	echo "Option '-$OPTARG' requires an argument, e.g. '-$OPTARG 5'." >&2
				return 1;;
		esac
	done
	
	# Now generate the password(s)
	# Despite best efforts with the PwdSet's, spaces still crept in, so there's a cursory tr -d ' ' to kill those

	# Let's start with checking for the Krypt option
	if [ "${PwdKrypt}" = "true" ]; then
		# Disallow columns
		if [ "${PwdCols}" = "true" ]; then
			printf "%s\n" "ERROR: Use of -C and -k together is disallowed.  Please choose one, but not both."
			return 1
		fi
		
		# Let's make sure we get the right number of passwords
		n=0
		while [ "${n}" -lt "${PwdNum}" ]; do
			# And let's get these variables figured out.  Needs to be inside the loop
			# to correctly pickp other arg values and to rotate properly
		        Pwd=$(tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -1) 2> /dev/null
			Salt=$(tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w 8 | head -1) 2> /dev/null

			# We check for python and if it's there, we use it
			if [ $(command -v python &>/dev/null) ]; then
	        		PwdSalted=$(python -c "import crypt; print crypt.crypt('${Pwd}', '\$1\$${Salt}')")
			# Otherwise, we failover to openssl
			else
				PwdSalted=$(openssl passwd -1 -salt ${Salt} ${Pwd})
			fi

			# Now let's print out the result.  People can always awk/cut to get just the crypted password
			# This should probably be tee'd off to a dotfile so that they can get the original password too
			printf "%s\n" "Original: ${Pwd} Crypted: ${PwdSalted}"
			
			# And we tick the counter up by one increment
			((n = n + 1))
		done
		return 0
	fi

	# Otherwise, let's just do plain old passwords.  This is considerably more straightforward
	# First, if the columns variable is false, don't pipe the output to 'column'
	if [ "${PwdCols}" = "false" ]; then
		tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -"${PwdNum}" 2> /dev/null
	# Otherwise, pipe it to 'column'.  I haven't bothered putting in a check, if column isn't available, just let bash tell the user
	elif [ "${PwdCols}" = "true" ]; then
		tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -"${PwdNum}" | column 2> /dev/null	
	fi

	# Uncomment for debug
	#echo "PwdSet is: ${PwdSet}" 
	#echo "PwdChars is: ${PwdChars}"
	#echo "PwdNum is: ${PwdNum}"
}

# A passphrase generator, because: why not?
# Note: This will only generate XKCD "Correct Horse Battery Staple" level phrases, which actually aren't that secure
# without some character randomisation.
# You should use the Schneier Method instead i.e. "This little piggy went to market" = "tlpWENT2m"
genphrase() {
	# Some examples of methods to do this (fastest to slowest):
	# shuf:         printf "%s\n" "$(shuf -n 3 ~/.pwords.dict | tr -d "\n")"
	# perl:		printf "%s\n" "perl -nle '$word = $_ if rand($.) < 1; END { print $word }' ~/.pwords.dict"
	# sed:		printf "$s\n" "sed -n $((RANDOM%$(wc -l < ~/.pwords.dict)+1))p ~/.pwords.dict"
	# python:	printf "%s\n" "$(python -c 'import random, sys; print("".join(random.sample(sys.stdin.readlines(), "${PphraseWords}")).rstrip("\n"))' < ~/.pwords.dict | tr -d "\n")"
	# oawk/nawk:	printf "%s\n" "$(for i in {1..3}; do sed -n "$(echo "$RANDOM" $(wc -l <~/.pwords.dict) | awk '{ printf("%.0f\n",(1.0 * $1/32768 * $2)+1) }')p" ~/.pwords.dict; done | tr -d "\n")"
	# gawk:         printf "%s\n" "$(awk 'BEGIN{ srand(systime() + PROCINFO["pid"]); } { printf( "%.5f %s\n", rand(), $0); }' ~/.pwords.dict | sort -k 1n,1 | sed 's/^[^ ]* //' | head -3 | tr -d "\n")"
	# sort -R:      printf "%s\n" "$(sort -R ~/.pwords.dict | head -3 | tr -d "\n")"
	# bash $RANDOM: printf "%s\n" "$(for i in $(<~/.pwords.dict); do echo "$RANDOM $i"; done | sort | cut -d' ' -f2 | head -3 | tr -d "\n")"

	# perl, sed, oawk/nawk and bash are the most portable options in order of speed.  The bash $RANDOM example is horribly slow, but reliable.  Avoid if possible.

        # First, double check that the dictionary file exists.  .bash_profile should normally take care of this
        if [ ! -f ~/.pwords.dict ] ; then
                if [ "$(uname)" = "SunOS" ] ; then
                        words=/usr/dict/words
                        /usr/xpg4/bin/grep -E '^.{4,7}$' "${words}" > ~/.pwords.dict
                else
                        words=/usr/share/dict/words
                        grep -E '^.{4,7}$' "${words}" > ~/.pwords.dict
                fi
        fi

	# Declare OPTIND as local for safety
	local OPTIND

	# Default the vars
	PphraseWords=3
	PphraseNum=1
	PphraseCols="False"

	while getopts ":Cw:n:h" Flags; do
		case "${Flags}" in
			C)	PphraseCols="True";;
			w)	PphraseWords="${OPTARG}";;
			n)	PphraseNum="${OPTARG}";;
			h)	printf "%s\n" "genphrase - a basic passphrase generator" \
				"Optional Arguments:" \
				"-C [attempt to output into columns (Default:off)]" \
				"-w [number of random words to use (Default:${PphraseWords})]" \
				"-n [number of passphrases to generate (Default:${PphraseNum})]" \
				"-h [help]"
				return 0;;

			\?)	echo "ERROR: Invalid option: '-$OPTARG'.  Try 'genphrase -h' for usage." >&2
				return 1;;
			
			:)	echo "Option '-$OPTARG' requires an argument. e.g. '-$OPTARG 10'" >&2
				return 1;;
		esac
	done
	
	# Now generate the passphrase(s)
	# First we test to see if shuf is available
	command -v shuf &>/dev/null
	# If the exit code is 0, then we can use shuf!
	if [ $? = 0 ]; then
#		echo "Using shuf!" #Debug
		if [ "${PphraseCols}" = "True" ]; then
			# Now we use a loop to run the number of times required to match the -n setting
			# Brace expansion can't readily take a variable e.g. {1..$var} so we have to iterate instead
			# Obviously this will have to be run a sufficient number of times to make the use of
			# 'column' worth it.  Fortunately shuf is very fast.
	#		echo "Columns true" #Debug
			n=0
			while [[ $n -lt "${PphraseNum}" ]]; do
				printf "%s\n" "$(shuf -n "${PphraseWords}" ~/.pwords.dict | tr -d "\n")" 
				let ++n
			done | column
		else
	#		echo "Columns false" #Debug
			n=0
			while [[ $n -lt "${PphraseNum}" ]]; do
				printf "%s\n" "$(shuf -n "${PphraseWords}" ~/.pwords.dict | tr -d "\n")" 
				let ++n
			done
		fi
		return 0 # Prevent subsequent run of perl/bash
	fi	
	# Next we try perl, installed almost everywhere and reasonably fast
	# For portability we have to be a bit more hands-on with our loops, which impacts performance
	command -v perl &>/dev/null
	if [ $? = 0 ]; then
#		echo "Using perl!" #Debug
		if [ "${PphraseCols}" = "True" ]; then
#			echo "Columns true" #Debug
			n=0
			while [[ $n -lt "${PphraseNum}" ]]; do
				w=0
				while [[ $w -lt "${PphraseWords}" ]]; do
					printf "%s\n" "$(perl -nle '$word = $_ if rand($.) < 1; END { print $word }' ~/.pwords.dict)"
					((w = w + 1))
				done | tr -d "\n"
				printf "\n"
	                ((n = n + 1))
			done | column
		else
#			echo "Columns false" #Debug
			n=0
			while [[ $n -lt "${PphraseNum}" ]]; do
				w=0
				while [[ $w -lt "${PphraseWords}" ]]; do
					printf "%s\n" "$(perl -nle '$word = $_ if rand($.) < 1; END { print $word }' ~/.pwords.dict)"
					((w = w + 1));
				done | tr -d "\n"
				printf "\n"
			((n = n + 1))
			done
		fi
	# Otherwise, we switch to bash, which is slower still
	# Do NOT use the "randomise then sort the dictionary" algorithm shown at the start of this function
	# It is BRUTALLY slow.  The method shown here is almost as fast as perl.
        elif [ $? = 1 ]; then
#           echo "Using bash!" #debug
                if [ "${PphraseCols}" = "True" ]; then
#                       echo "Columns true" #Debug
                        n=0
                        while [[ $n -lt "${PphraseNum}" ]]; do
                                w=0
                                while [[ $w -lt "${PphraseWords}" ]]; do
                                        printf "%s\n" "$(head -n $((RANDOM%$(wc -l <~/.pwords.dict))) ~/.pwords.dict | tail -1)"
                                        ((w = w + 1))
                                done | tr -d "\n"
                                printf "\n"
                        ((n = n + 1))
                        done | column
                else
#                       echo "Columns false" #Debug
                        n=0
                        while [[ $n -lt "${PphraseNum}" ]]; do
                                w=0
                                while [[ $w -lt "${PphraseWords}" ]]; do
                                        printf "%s\n" "$(head -n $((RANDOM%$(wc -l <~/.pwords.dict))) ~/.pwords.dict | tail -1)"
                                        ((w = w + 1))
                                done | tr -d "\n"
                                printf "\n"     
                        ((n = n + 1))
                        done
                fi
        fi
}

# Password strength check function.  Can be fed a password most ways.
pwcheck () {
        # Read password in, if it's blank, prompt the user
        if [ "${*}" = "" ]; then
                read -resp $'Please enter the password/phrase you would like checked:\n' PwdIn
        else
                # Otherwise, whatever is fed in is the password to check
                PwdIn="${*}"
        fi

        # Check password, attempt with cracklib-check, failover to something a little more exhaustive
        if [ -f /usr/sbin/cracklib-check ]; then
                Result="$(echo "${PwdIn}" | /usr/sbin/cracklib-check)"
                Okay="$(awk -F': ' '{ print $2}' <<<"${Result}")"
	else	
		# I think we have a common theme here.  Writing portable code sucks, but it keeps things interesting.
		
		#printf "%s\n" "pwcheck: Attempting this the hard way" #Debug
		# Force 3 of the following complexity categories:  Uppercase, Lowercase, Numeric, Symbols, No spaces, No dicts
		# Start by giving a credential score to be subtracted from, then default the initial vars
		CredCount=4
		PWCheck="true"
		ResultChar="Character count: OK"
		ResultDigit="Digit count: OK"
		ResultUpper="UPPERCASE count: OK"
		ResultLower="lowercase count: OK"
		ResultPunct="Special character count: OK"
		ResultSpace="No spaces found: OK"
		ResultDict="Doesn't seem to match any dictionary words: OK"
		Result="$(printf "%s\n" "${PwdIn}:" "${ResultChar}" "${ResultSpace}" "${ResultDict}" "${ResultDigit}" "${ResultUpper}" "${ResultLower}" "${ResultPunct}")"

		while [ "${PWCheck}" = "true" ]; do
			# Start cycling through each complexity requirement	
			if [[ "${#PwdIn}" -lt "8" ]]; then
				Result="${PwdIn}: Password must have a minimum of 8 characters.  Further testing stopped."
				CredCount=0
				PWCheck="false" # Instant failure for character count
			elif [[ "${PwdIn}" == *[[:blank:]]* ]]; then
                                Result="${PwdIn}: Password cannot contain spaces.  Further testing stopped."
                                CredCount=0 
				PWCheck="false" # Instant failure for spaces
			fi
			# Check against the dictionary
			if grep -q "${PwdIn}" /usr/share/dict/words; then
                        	Result="${PwdIn}: Password cannot contain a dictionary word."
                        	CredCount=0 # Punish hard for dictionary words
			fi
			# Check for a digit
			echo "${PwdIn}" | grep '[[:digit:]]' >/dev/null
			if [ $? != "0" ]; then
				ResultDigit="Password should contain at least one digit."
				((CredCount = CredCount - 1))
			fi
			# Check for UPPERCASE
                        echo "${PwdIn}" | grep '[[:upper:]]' >/dev/null
                        if [ $? != "0" ]; then
                                ResultUpper="Password should contain at least one uppercase letter."
                                ((CredCount = CredCount - 1))
                        fi
			# Check for lowercase
                        echo "${PwdIn}" | grep '[[:lower:]]' >/dev/null
                        if [ $? != "0" ]; then
                                ResultLower="Password should contain at least one lowercase letter."
                                ((CredCount = CredCount - 1))
                        fi
			# Check for special characters
                        echo "${PwdIn}" | grep '[[:punct:]]' >/dev/null
                        if [ $? != "0" ]; then
                                ResultPunct="Password should contain at least one special character."
                                ((CredCount = CredCount - 1))
                        fi
			PWCheck="false" #Exit condition for the loop
		done

		#printf "%s\n" "CredCount = ${CredCount}" #debug
	
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
                printf "%s\n" "The password/phrase passed my testing."
                return 0
        else
                printf "%s\n" "The check failed:" "${Result}" "Please try again."
                return 1
        fi
}

# flocate function.  This gives a search function that blends find and locate
# Will obviously only work where locate lives, so Solaris will mostly be out of luck
# Usage: flocate searchterm1 searchterm2 searchterm[n]
# Source: http://solarum.com/v.php?l=1149LV99
flocate() {
if [ "$(uname)" = "SunOS" ] ; then
        echo "Sorry, this only works on Linux"
        return 1
fi
if [ $# -gt 1 ] ; then
        display_divider=1
else
        display_divider=0
fi

current_argument=0
total_arguments=$#
while [ "${current_argument}" -lt "${total_arguments}" ] ; do
        current_file=$1
        if [ "${display_divider}" = "1" ] ; then
                echo "----------------------------------------"
                echo "Matches for ${current_file}"
                echo "----------------------------------------"
        fi

        filename_re="^\(.*/\)*$( echo ${current_file} | sed s%\\.%\\\\.%g )$"
        locate -r "${filename_re}"
        shift
        (( current_argument = current_argument + 1 ))
done
}

# Enable piping to Windows Clipboard from with PuTTY
# Uses modified PuTTY from http://ericmason.net/2010/04/putty-ssh-windows-clipboard-integration/
wclip() {
	echo -ne '\e''[5i'
	cat $*
	echo -ne '\e''[4i'
	echo "Copied to Windows clipboard" 1>&2
}

# Enable X-Windows for cygwin, finds and assigns an available display env variable.
# This will need to be removed for old versions of bash e.g. 2.03, which can't handle the math.
# Attempting to version check around that hasn't worked.

# To use, issue 'myx', and then 'ssh -X [host] "/some/path/to/gui-application" &'

# First we check if we're on Solaris, because Solaris doesn't like "uname -o"
if [ "$(uname)" != "SunOS" ] ; then
	if [ "$(uname -o)" = "Cygwin" ] ; then
		myx() {
		a=/tmp/.X11-unix/X
		for ((i=351;i<500;i++)) ; do
		b=$a$i
		if [[ ! -S $b ]] ; then
			c=$i
			break
		fi
		done
		export DISPLAY=:$c
		echo export DISPLAY=:$c
		X :$c -multiwindow >& /dev/null &
		xterm -fn 9x15bold -bg black -fg orange -sb &
		}
	fi
fi

# Standardise the Command Prompt
# First, let's map some colours, uncomment to use:
#txtblk='\e[0;30m\]' # Black - Regular
#txtred='\e[0;31m\]' # Red
txtgrn='\e[0;32m\]' # Green
#txtylw='\e[0;33m\]' # Yellow
#txtblu='\e[0;34m\]' # Blue
#txtpur='\e[0;35m\]' # Purple
#txtcyn='\e[0;36m\]' # Cyan
#txtwht='\e[0;37m\]' # White
#bldblk='\e[1;30m\]' # Black - Bold
bldred='\e[1;31m\]' # Red
#bldgrn='\e[1;32m\]' # Green
#bldylw='\e[1;33m\]' # Yellow
#bldblu='\e[1;34m\]' # Blue
#bldpur='\e[1;35m\]' # Purple
#bldcyn='\e[1;36m\]' # Cyan
#bldwht='\e[1;37m\]' # White
#unkblk='\e[4;30m\]' # Black - Underline
#undred='\e[4;31m\]' # Red
#undgrn='\e[4;32m\]' # Green
#undylw='\e[4;33m\]' # Yellow
#undblu='\e[4;34m\]' # Blue
#undpur='\e[4;35m\]' # Purple
#undcyn='\e[4;36m\]' # Cyan
#undwht='\e[4;37m\]' # White
#bakblk='\e[40m\]'   # Black - Background
#bakred='\e[41m\]'   # Red
#bakgrn='\e[42m\]'   # Green
#bakylw='\e[43m\]'   # Yellow
#bakblu='\e[44m\]'   # Blue
#bakpur='\e[45m\]'   # Purple
#bakcyn='\e[46m\]'   # Cyan
#bakwht='\e[47m\]'   # White
txtrst='\e[0m\]'    # Text Reset

# Throw it all together, starting with the portable option 
if [ "$(uname)" != "Linux" ]; then
	export PS1="\\[${txtrst}${bldred}[\$(date +%y%m%d/%H:%M)]\[${txtrst}${txtgrn}[\u@\h\[${txtrst} \W\[${txtgrn}]\[${txtrst}$ "
else
# Otherwise use tput as it's more predictable/readable.  Generated via kirsle.net/wizards/ps1.html
	export PS1="\\[$(tput bold)\]\[$(tput setaf 1)\][\$(date +%y%m%d/%H:%M)]\[$(tput sgr0)\]\[$(tput setaf 2)\][\u@\h \[$(tput setaf 7)\]\W\[$(tput setaf 2)\]]\[$(tput setaf 7)\]$ \[$(tput sgr0)\]"
fi

# NOTE for customisation: Any non-printing escape characters must be enclosed, otherwise bash will miscount
# and get confused about where the prompt starts.  All sorts of line wrapping weirdness and prompt overwrites
# will then occur.  This is why all of the variables have '\]' enclosing them.  Don't mess with that.
# 
# Bad:		\\[\e[0m\e[1;31m[\$(date +%y%m%d/%H:%M)]\[\e[0m
# Better:	\\[\e[0m\]\e[1;31m\][\$(date +%y%m%d/%H:%M)]\[\e[0m\]

# The double backslash at the start also helps with this behaviour.

# Check the window size after each command and, if necessary,
# Update the values of LINES and COLUMNS.
# This attempts to correct line-wrapping-over-prompt issues when a window is resized
shopt -s checkwinsize

# Set the bash history timestamp format
export HISTTIMEFORMAT="%F,%T "

# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoredups:ignorespace
 
# append to the history file, don't overwrite it
shopt -s histappend
 
# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# Sort out the PATH for Solaris
# First let's check the host to see what OS is present
if [ "$(uname)" = "SunOS" ] ; then
        # Ok, it's Solaris.  So let's set the PATH for that:
        PATH=/bin:/usr/bin:/usr/local/bin:/opt/csw/bin:/usr/sfw/bin:
else
        # Not Solaris?  Must be Linux then:
        PATH=$PATH:$HOME/bin
fi
export PATH

# Sort out "Terminal Too Wide" issue in vi on Solaris
if [ "$(uname)" = "SunOS" ] ; then
        stty columns 140
fi

# Correct backspace behaviour for some troublesome Linux servers that don't abide by .inputrc
if [ "$(uname)" != "SunOS" ] ; then
        if tty --quiet ; then
                stty erase '^?'
        fi
fi

# Disable ctrl+s (XOFF) in PuTTY
stty ixany
stty ixoff -ixon
