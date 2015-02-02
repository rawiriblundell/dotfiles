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

# Widen diff out to the width of the console
# Useful for side by side e.g. diff -y
alias diff='diff -W $(( $(tput cols) - 2 ))'

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
	PwdKryptMode=1
	KryptMethod=
	ReqSet=
	PwdCheck="false"
	SpecialChar="false"
	InputChars=(\! \@ \# \$ \% \^ \( \) \_ \+ \? \> \< \~)

	while getopts ":Cc:Dhk:Ln:SsUY" Flags; do
		case "${Flags}" in
			C)	PwdCols="true";;
			c)	PwdChars="${OPTARG}";;
			D)	ReqSet="${ReqSet}[0-9]+"
				PwdCheck="true";;
			h)	printf "%s\n" "genpasswd - a poor sysadmin's pwgen" \
				"" "Usage: genpasswd [options]" "" \
				"Optional arguments:" \
				"-C [Attempt to output into columns (Default:off)]" \
				"-c [Number of characters. Minimum is 4. (Default:${PwdChars})]" \
				"-D [Require at least one digit (Default:off)]" \
                                "-h [Help]" \
				"-k [Krypt, generates a crypted/salted password for tools like 'usermod -p' and 'chpasswd -e'" \
				"    use of -C [columns] will be disallowed when this mode is enabled." \
				"    Crypt method can be set using '-k 1' (MD5, default), '-k 5' (SHA256) or '-k 6' (SHA512)" \
				"    Any other arguments fed to '-k' will default to MD5.  (Default:off)]" \
				"-L [Require at least one lowercase character (Default:off)]" \
				"-n [Number of passwords (Default:${PwdNum})]" \
				"-s [Strong mode, seeds a limited amount of special characters into the mix (Default:off)]" \
				"-S [Stronger mode, complete mix of characters (Default:off)]" \
				"-U [Require at least one uppercase character (Default:off)]" \
				"-Y [Require at least one special character (Default:off)]" \
				"" "Note: Broken Pipe errors, (older bash versions) can be ignored"
				return 0;;
			k)	PwdKrypt="true"
				PwdKryptMode="${OPTARG}";;
			L)	ReqSet="${ReqSet}[a-z]+"
				PwdCheck="true";;
                        n)      PwdNum="${OPTARG}";;
                                # Attempted to randomise special chars using 7 random chars from [:punct:] but reliably
                                # got "reverse collating sequence order" errors.  Seeded 9 special chars manually instead.
                        s)      PwdSet="[:alnum:]#$&+/<}^%@";;
                        S)      PwdSet="[:graph:]";;
			U)	ReqSet="${ReqSet}[A-Z]+"
				PwdCheck="true";;
				# If a special character is required, we feed in more special chars than in -s
				# This improves performance a bit by better guaranteeing seeding and matching
			Y)	#ReqSet="${ReqSet}[#$&\+/<}^%?@!]+"
				SpecialChar="true"
				PwdCheck="true";;
			\?)	echo "ERROR: Invalid option: $OPTARG.  Try 'genpasswd -h' for usage." >&2
				return 1;;
			
			:)	echo "Option '-$OPTARG' requires an argument, e.g. '-$OPTARG 5'." >&2
				return 1;;
		esac
	done

	# We need to check that the character length is more than 4 to protect against
	# infinite loops caused by the character checks.  i.e. 4 character checks on a 3 character password
	if [[ "${PwdChars}" -lt 4 ]]; then
		printf "%s\n" "ERROR: Password length must be greater than four characters."
		return 1
	fi

        # Now generate the password(s)
        # Despite best efforts with the PwdSet's, spaces still crept in, so there's a cursory tr -d ' ' to kill those

        # If these two are false, there's no point doing further checks.  We just slam through
	# the absolute simplest bit of code in this function.  This is here for performance reasons.
	if [[ "${PwdKrypt}" = "false" && "${PwdCheck}" = "false" ]]; then
		if [[ "${PwdCols}" = "false" ]]; then
                        tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -"${PwdNum}" 2> /dev/null
                elif [[ "${PwdCols}" = "true" ]]; then
                        tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -"${PwdNum}" | column 2> /dev/null
                fi
	fi

	# Let's start with checking for the Krypt option
	if [[ "${PwdKrypt}" = "true" ]]; then
		# Disallow columns
		if [[ "${PwdCols}" = "true" ]]; then
			printf "%s\n" "ERROR: Use of -C and -k together is disallowed.  Please choose one, but not both."
			return 1
		fi
		
		# Now figure out the crypt mode
		# 1 = MD5
		# 5 = SHA256
		# 6 = SHA512
		# We don't want to mess around with other options as it requires more error handling than I can be bothered with
		# If the crypt mode isn't 5 or 6, default it to 1, otherwise leave it be
		if [[ "${PwdKryptMode}" -ne 5 && "${PwdKryptMode}" -ne 6 ]]; then
			# Otherwise, default to MD5.  This catches 
			PwdKryptMode=1
		fi
		
		# Let's make sure we get the right number of passwords
		n=0
		while [[ "${n}" -lt "${PwdNum}" ]]; do
			# And let's get these variables figured out.  Needs to be inside the loop
			# to correctly pickup other arg values and to rotate properly
		        Pwd=$(tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -1) 2> /dev/null
			Salt=$(tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w 8 | head -1) 2> /dev/null
			
                        # Now we ensure that Pwd matches any character requirements
                        if [[ "${PwdCheck}" = "true" ]]; then
                                while ! printf "%s\n" "${Pwd}" | egrep "${ReqSet}" &> /dev/null; do
                                        Pwd=$(tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -1 2> /dev/null)
                                done
                        fi

                        # If -Y is set, we need to mix in a special character
                        if [[ "${SpecialChar}" = "true" ]]; then
                                Shuffle=$((RANDOM % ${#InputChars[@]}))
                                PwdSeed=${InputChars[*]:$Shuffle:1}
                                SeedLoc=$((RANDOM % ${#Pwd}))
                                ((PwdLen = ${#Pwd} - 1))
                                Pwd="${Pwd:0:$PwdLen}"
                                Pwd=$(printf "%s\n" "${Pwd}" | sed "s/^\(.\{$SeedLoc\}\)/\1${PwdSeed}/")
                        fi

			# We check for python and if it's there, we use it
			if command -v python &>/dev/null; then
	        		PwdSalted=$(python -c "import crypt; print crypt.crypt('${Pwd}', '\$${PwdKryptMode}\$${Salt}')")
			# Next we failover to perl
			elif command -v perl &>/dev/null; then
				PwdSalted=$(perl -e "print crypt('${Pwd}','\$${PwdKryptMode}\$${Salt}\$')")
			# Otherwise, we failover to openssl
			elif ! command -v openssl &>/dev/null; then
				# Sigh, Solaris you pain in the ass
                                for d in /usr/local/ssl/bin /opt/csw/bin /usr/sfw/bin; do
                                       if [ -f "${d}/openssl" ]; then
                                                OpenSSL="${d}/openssl"
                                        else
                                                OpenSSL=openssl
                                        fi
                                done

                		# We can only generate an MD5 password using OpenSSL
				PwdSalted=$("${OpenSSL}" passwd -1 -salt "${Salt}" "${Pwd}")
				KryptMethod=OpenSSL
			fi

			# Now let's print out the result.  People can always awk/cut to get just the crypted password
			# This should probably be tee'd off to a dotfile so that they can get the original password too
			printf "%s\n" "Original: ${Pwd} Crypted: ${PwdSalted}"
			
			# And we tick the counter up by one increment
			((n = n + 1))
		done
		# In case OpenSSL is used, give an FYI before we exit out
		if [ "${KryptMethod}" = "OpenSSL" ]; then
			printf "%s\n" "Password encryption was handled by OpenSSL which is only MD5 capable."
		fi
		return 0
	fi

	# Otherwise, let's just do plain old passwords.  This is considerably more straightforward
	# First, if the character check variable is true, then we go through that process
	if [[ "${PwdCheck}" = "true" ]]; then
		# We handle for no columns, running a loop until the required number of
		# passwords is generated
		if [[ "${PwdCols}" = "false" ]]; then
			n=0
			while [[ "${n}" -lt "${PwdNum}" ]]; do
				Pwd=$(tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -1 2> /dev/null)
				# Now we run through a loop that will grep out generated passwords that match
				# the required character classes.  For portability, we shunt the lot to /dev/null
				# Because Solaris egrep doesn't behave with -q or -s as it should.
				while ! printf "%s\n" "${Pwd}" | egrep "${ReqSet}" &> /dev/null; do
					Pwd=$(tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -1 2> /dev/null)
				done
				# For each matched password, print it out, iterate and loop again.
				# But first we need to check if -Y is set, and if so, force in a random special character
                               	if [[ "${SpecialChar}" = "true" ]]; then
					# Generate a random element number to select from the special characters array
					Shuffle=$((RANDOM % ${#InputChars[@]}))
					# Using the above, get the randomly selected character from the array
					PwdSeed=${InputChars[*]:$Shuffle:1}
					# Choose a random location within the max password length in which to insert it
					SeedLoc=$((RANDOM % ${#Pwd}))
					# Calculate the password length minus 1, as we need to shorten the password
					((PwdLen = ${#Pwd} - 1))
					# Shorten the password in order to make space for the inserted character
					Pwd="${Pwd:0:$PwdLen}"
					# Print out the password, then use sed to insert the special character into the preselected place
					printf "%s\n" "${Pwd}" | sed "s/^\(.\{$SeedLoc\}\)/\1${PwdSeed}/"
				# If -Y isn't set, just print it out.  Easy!
				else
					printf "%s\n" "${Pwd}"
				fi
	                       ((n = n + 1))
			done
		# Otherwise, pipe it to 'column'.  I haven't bothered putting in a check, if column isn't available, just let bash tell the user
		elif [[ "${PwdCols}" = "true" ]]; then
			n=0
	                while [[ "${n}" -lt "${PwdNum}" ]]; do
        	                Pwd=$(tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -1 2> /dev/null)
                        	while ! printf "%s\n" "${Pwd}" | egrep "${ReqSet}" &> /dev/null; do
                                        Pwd=$(tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -1 2> /dev/null)
	                        done
                                if [[ "${SpecialChar}" = "true" ]]; then
                                        Shuffle=$((RANDOM % ${#InputChars[@]}))
                                        PwdSeed=${InputChars[*]:$Shuffle:1}
                                        SeedLoc=$((RANDOM % ${#Pwd}))
                                        ((PwdLen = ${#Pwd} - 1))
                                        Pwd="${Pwd:0:$PwdLen}"
                                        printf "%s\n" "${Pwd}" | sed "s/^\(.\{$SeedLoc\}\)/\1${PwdSeed}/"
                                else
                                        printf "%s\n" "${Pwd}"
                                fi
                	        ((n = n + 1))
	                done | column 2> /dev/null
		fi
	fi
	
	# Uncomment for debug
	#echo "ReqSet is: ${ReqSet}"
	#echo "PwdSet is: ${PwdSet}" 
	#echo "PwdChars is: ${PwdChars}"
	#echo "PwdNum is: ${PwdNum}"
}

# A separate password encryption tool, so that you can encrypt passwords
# of your own choice, rather than depending on something that genpasswd has spat out
cryptpasswd() {
        # Declare OPTIND as local for safety
        local OPTIND

	# Default the vars
        Pwd="${1}"
        Salt=$(tr -dc '[:graph:]' < /dev/urandom | tr -d ' ' | fold -w 8 | head -1) 2> /dev/null
	PwdKryptMode="${2}"
	
	if [ "${1}" = "" ]; then
		printf "%s\n" "cryptpasswd - a tool for hashing passwords" \
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
        # Next we failover to perl
        elif command -v perl &>/dev/null; then
        	PwdSalted=$(perl -e "print crypt('${Pwd}','\$${PwdKryptMode}\$${Salt}\$')")
        # Otherwise, we failover to openssl
        elif ! command -v openssl &>/dev/null; then
		# Sigh, Solaris you pain in the ass
                for d in /usr/local/ssl/bin /opt/csw/bin /usr/sfw/bin; do
                        if [ -f "${d}/openssl" ]; then
                                OpenSSL="${d}/openssl"
                        else
                                OpenSSL=openssl
                        fi
                done

                # We can only generate an MD5 password using OpenSSL
              	PwdSalted=$("${OpenSSL}" passwd -1 -salt "${Salt}" "${Pwd}")
                KryptMethod=OpenSSL
	fi

        # Now let's print out the result.  People can always awk/cut to get just the crypted password
        # This should probably be tee'd off to a dotfile so that they can get the original password too
        printf "%s\n" "Original: ${Pwd} Crypted: ${PwdSalted}"

        # In case OpenSSL is used, give an FYI before we exit out
        if [ "${KryptMethod}" = "OpenSSL" ]; then
        	printf "%s\n" "Password encryption was handled by OpenSSL which is only MD5 capable."
        fi
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
	PphraseSeed="False"
	PphraseSeedDoc="False"
	SeedWord=

	while getopts ":Chn:s:Sw:" Flags; do
		case "${Flags}" in
			C)	PphraseCols="True";;
			h)	printf "%s\n" "genphrase - a basic passphrase generator" \
				"Optional Arguments:" \
				"-C [attempt to output into columns (Default:off)]" \
				"-h [help]" \
				"-n [number of passphrases to generate (Default:${PphraseNum})]" \
				"-s [seed your own word.  Use 'genphrase -S' to read about this option.]" \
				"-S [explanation for the word seeding option: -s]" \
				"-w [number of random words to use (Default:${PphraseWords})]"
				return 0;;
			n)	PphraseNum="${OPTARG}";;
			s)	PphraseSeed="True"
				SeedWord="[${OPTARG}]";;
			S)	PphraseSeedDoc="True";;
			w)	PphraseWords="${OPTARG}";;
			\?)	echo "ERROR: Invalid option: '-$OPTARG'.  Try 'genphrase -h' for usage." >&2
				return 1;;
			
			:)	echo "Option '-$OPTARG' requires an argument. e.g. '-$OPTARG 10'" >&2
				return 1;;
		esac
	done
	
	# If -S is selected, print out the documentation for word seeding
	if [ "${PphraseSeedDoc}" = "True" ]; then
                printf "%s\n"   "======================================================================" \
                                "genphrase and the -s option: Why you would want to seed your own word?" \
                                "======================================================================" \
                                "One method for effectively using passphrases is to choose at least two" \
                                "random words and to seed those two words with a task specific word." \
                                "So let's take two words:" \
                                "---" "pings genre" "---" \
                                "Now if we capitalise both words to get CamelCasing, we meet the usual"\
                                "upper and lowercase password requirements, as well as very likely" \
                                "meeting the password length requirement: 'PingsGenre'" ""\
                                "So then we add a task specific word: Let's say this passphrase is for" \
                                "your online banking, so we add the word 'bank' into the mix and get:" \
                                "'PingsGenrebank'" "" \
                                "For social networking, you might have 'PingsGenreFBook' and so on." \
                                "The random words are the same, but the task-specific word is the key." \
                                "" "Problem is, this isn't good enough.  The reality is that" \
                                "CorrectHorseBatteryStaple isn't that secure (http://goo.gl/ZGlkfm)." \
                                "So we need to randomise those words, introduce some special characters," \
                                "and some numbers.  'PingsGenrebank' becomes 'Pings{B4nk}Genre'" \
                                "and likewise 'PingsGenreFBook' becomes '(FB0ok)GenrePings'." \
                                "" "So, this is a very easy to remember system which meets most usual" \
                                "password requirements, and it makes most lame password checkers happy." \
                                "You could also argue that this borders on multi-factor auth" \
                                "i.e. something you are/know/have." \
                                "" "genphrase will always put the seeded word in square brackets and if" \
                                "possible it will randomise its location in the phrase, it's over to" \
                                "you to make sure that your seeded word has numerals etc." "" \
                                "Note: You can always use genphrase to generate the base phrase and" \
                                "      then manually embellish it to your taste."
		return 0
	fi
	
	# Next test if a word is being seeded in
	if [ "${PphraseSeed}" = "True" ]; then
		# If so, make space for the seed word
		((PphraseWords = PphraseWords - 1))
	fi
	
	# Now generate the passphrase(s)
	# First we test to see if shuf is available
	if command -v shuf &>/dev/null; then
#		echo "Using shuf!" #Debug
		if [ "${PphraseCols}" = "True" ]; then
			# Now we use a loop to run the number of times required to match the -n setting
			# Brace expansion can't readily take a variable e.g. {1..$var} so we have to iterate instead
			# Obviously this will have to be run a sufficient number of times to make the use of
			# 'column' worth it.  Fortunately shuf is very fast.
#			echo "Columns true" #Debug
			n=0
			while [[ $n -lt "${PphraseNum}" ]]; do
				#Older methods left commented out to show the evolution of this function
				#printf "%s\n" "$(shuf -n "${PphraseWords}" ~/.pwords.dict | tr -d "\n")" 
				#read -ra words <<< $(shuf -n "${PphraseWords}" ~/.pwords.dict) && printf "%s\n" $(tr -d " " <<< "${words[@]^}")
				
				# Create an array with the seeded word in place if it's used
				#PphraseArray=("${SeedWord}" $(shuf -n "${PphraseWords}" ~/.pwords.dict))
				# Read the array in and shuffle it
                                #read -ra words <<< $(printf "%s\n" ${PphraseArray[*]} | shuf)
                                # Now implement CamelCasing on the non-seed words and print the result
                                #printf "%s\n" "$(tr -d " " <<< "${words[@]^}")"
                                
                                # Well, I wanted to do it the above way, but Solaris got upset
                                # So instead we have to do it like some kind of barbarians
                                
                                # First let's create an array of shuffled words with their first char uppercased
                                DictWords=$(for i in $(shuf -n "${PphraseWords}" ~/.pwords.dict); \
                                        do InWord=$(echo "${i:0:1}" | tr '[:lower:]' '[:upper:]'); \
                                        OutWord=$InWord${i:1}; printf "%s\n" "${OutWord}"; done)
                                # Now we print out the seed word and the array, shuffle them, 
                                # and remove the the newlines, leaving a passphrase
                                printf "%s\n" "${SeedWord}" "${DictWords[@]}" | shuf | tr -d "\n"
                                printf "\n"
				let ++n
			done | column
		else
#			echo "Columns false" #Debug
			n=0
			while [[ $n -lt "${PphraseNum}" ]]; do
                                DictWords=$(for i in $(shuf -n "${PphraseWords}" ~/.pwords.dict); \
                                        do InWord=$(echo "${i:0:1}" | tr '[:lower:]' '[:upper:]'); \
                                        OutWord=$InWord${i:1}; printf "%s\n" "${OutWord}"; done)
                                printf "%s\n" "${SeedWord}" "${DictWords[@]}" | shuf | tr -d "\n"
                                printf "\n"
				let ++n
			done
		fi
		return 0 # Prevent subsequent run of perl/bash
	fi	
	# Next we try perl, installed almost everywhere and reasonably fast
	# For portability we have to be a bit more hands-on with our loops, which impacts performance
	if command -v perl &>/dev/null; then
#		echo "Using perl!" #Debug
		if [ "${PphraseCols}" = "True" ]; then
#			echo "Columns true" #Debug
			n=0
			while [[ $n -lt "${PphraseNum}" ]]; do
				#If it's there, print the seedword
                                printf "%s" "${SeedWord}"
                                # And now get the random words
				w=0
				while [[ $w -lt "${PphraseWords}" ]]; do
					printf "%s\n" "$(perl -nle '$word = $_ if rand($.) < 1; END { print "\u$word" }' ~/.pwords.dict)"
					((w = w + 1))
				done | tr -d "\n"
				printf "\n"
	                ((n = n + 1))
			done | column
		else
#			echo "Columns false" #Debug
			n=0
			while [[ $n -lt "${PphraseNum}" ]]; do
                                printf "%s" "${SeedWord}"
				w=0
				while [[ $w -lt "${PphraseWords}" ]]; do
					printf "%s\n" "$(perl -nle '$word = $_ if rand($.) < 1; END { print "\u$word" }' ~/.pwords.dict)"
					((w = w + 1));
				done | tr -d "\n"
				printf "\n"
			((n = n + 1))
			done
		fi
	# Otherwise, we switch to bash, which is slower still
	# Do NOT use the "randomise then sort the dictionary" algorithm shown at the start of this function
	# It is BRUTALLY slow.  The method shown here is almost as fast as perl.
        else
#           echo "Using bash!" #debug
                if [ "${PphraseCols}" = "True" ]; then
#                       echo "Columns true" #Debug
                        n=0
                        while [[ $n -lt "${PphraseNum}" ]]; do
                        	# If it's there, print the seedword
                                printf "%s" "${SeedWord}"
                                # And now get the random words
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
                        	printf "%s" "${SeedWord}"
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
# To use, issue 'myx', and then 'ssh -X [host] "/some/path/to/gui-application" &'

# First we check if we're on Solaris, because Solaris doesn't like "uname -o"
if [ "$(uname)" != "SunOS" ] ; then
        if [ "$(uname -o)" = "Cygwin" ] ; then
                myx() {
                        a=/tmp/.X11-unix/X
                        #for ((i=351;i<500;i++)) ; do #breaks older versions of bash, hence the next while loop
                        i=351
                        while [[ "${i}" -lt 500 ]]; do
                                b=$a$i
                                if [[ ! -S $b ]] ; then
                                        c=$i
                                        break
                                fi
                        i++
                        done
                        export DISPLAY=:$c
                        echo export DISPLAY=:$c
                        X :$c -multiwindow >& /dev/null &
                        xterm -fn 9x15bold -bg black -fg orange -sb &
                }
        fi
fi

# Provide a faster-than-scp file transfer function
# From http://intermediatesql.com/linux/scrap-the-scp-how-to-copy-data-fast-using-pigz-and-nc/
ncp() {
	FileFull=$1
	RemoteHost=$2

	FileDir=$(dirname "${FileFull}")
	FileName=$(basename "${FileFull}")
	LocalHost=$(hostname)

	ZipTool=pigz
	NCPort=8888

	tar -cf - -C "${FileDir} ${FileName}" | pv -s "$(du -sb "${FileFull}" | awk '{s += $1} END {printf "%d", s}')" | "${ZipTool}" | nc -l "${NCPort}" &
	ssh "${RemoteHost}" "nc ${LocalHost} ${NCPort} | ${ZipTool} -d | tar xf - -C ${FileDir}"
}

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
bldylw='\e[1;33m\]' # Yellow
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
if [[ "$(uname)" != "Linux" ]]; then
	# Check if we're root, and adjust to suit
	if [[ "${EUID}" -eq 0 ]]; then
		export PS1="\\[${txtrst}${bldred}[\$(date +%y%m%d/%H:%M)]\[${txtrst}${bldylw}[\u@\h\[${txtrst} \W\[${bldylw}]\[${txtrst}$ "
	# Otherwise show the usual prompt
	else
		export PS1="\\[${txtrst}${bldred}[\$(date +%y%m%d/%H:%M)]\[${txtrst}${txtgrn}[\u@\h\[${txtrst} \W\[${txtgrn}]\[${txtrst}$ "
	fi
	# Alias the root PS1 into sudo for edge cases
	alias sudo="PS1='\\[${txtrst}${bldred}[\$(date +%y%m%d/%H:%M)]\[${txtrst}${bldylw}[\u@\h\[${txtrst} \W\[${bldylw}]\[${txtrst}$ ' sudo"
# Otherwise use tput as it's more predictable/readable.  Generated via kirsle.net/wizards/ps1.html
else
	# Check if we're root, and adjust to suit
	if [[ "${EUID}" -eq 0 ]]; then
		export PS1="\\[$(tput bold)\]\[$(tput setaf 1)\][\$(date +%y%m%d/%H:%M)]\[$(tput setaf 3)\][\u@\h \[$(tput setaf 7)\]\W\[$(tput setaf 3)\]]\[$(tput setaf 7)\]$ \[$(tput sgr0)\]"
	# Otherwise show the usual prompt
	else
		export PS1="\\[$(tput bold)\]\[$(tput setaf 1)\][\$(date +%y%m%d/%H:%M)]\[$(tput sgr0)\]\[$(tput setaf 2)\][\u@\h \[$(tput setaf 7)\]\W\[$(tput setaf 2)\]]\[$(tput setaf 7)\]$ \[$(tput sgr0)\]"
	fi
	# Alias the root PS1 into sudo for edge cases
	alias sudo="PS1='\\[$(tput bold)\]\[$(tput setaf 1)\][\$(date +%y%m%d/%H:%M)]\[$(tput setaf 3)\][\u@\h \[$(tput setaf 7)\]\W\[$(tput setaf 3)\]]\[$(tput setaf 7)\]$ \[$(tput sgr0)\]' sudo"
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
