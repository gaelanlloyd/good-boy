#!/bin/sh

# ------------------------------------------------------------------------------
#
# Good Boy
#
# Zero-dependency, native-FreeBSD bootstrapper in a smol, single sh script.
#
# By Gaelan Lloyd, 2026-05
#
# ------------------------------------------------------------------------------
#
# INSTRUCTIONS
#
# - Customize and add to Good Boy's playbooks below to suit your needs.
# - Upload this script to somewhere your instances can access.
# - Put any supporting files in a subdirectory in the same remote location.
# - As root: Download, mark executable, and whistle for him. What a good boy!
#
# ------------------------------------------------------------------------------
#
# EXAMPLE:
#
# cd ~/
# fetch https://your-bucket.s3.amazonaws.com/good-boy.sh
# chmod +x good-boy.sh
# ./good-boy.sh <playbook>
#
# ------------------------------------------------------------------------------
#
# MIT LICENSE
#
# Copyright (c) 2026 Gaelan Lloyd
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
# OR OTHER DEALINGS IN THE SOFTWARE.
#

# --- DEFINE GLOBALS -----------------------------------------------------------

INT_EXPECTED_ARGS=1

STR_TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
STR_TIME_START_PRETTY=$(date +"%H:%M:%S")
TIME_START=$(date +"%s")

DIR_WORK=$(mktemp -d)

STR_USER_NAME="btorres"
DIR_USER_HOME="/home/btorres"

STR_SSH_KEY_TYPE="ed25519"
# STR_SSH_KEY_TYPE="rsa"
FILEPATH_USER_SSH_PRIVATE_KEY="$DIR_USER_HOME/.ssh/id_rsa"
FILEPATH_USER_SSH_PUBLIC_KEY="$DIR_USER_HOME/.ssh/id_rsa.pub"

URL_REMOTE_PATH_ROOT="https://example.com/bootstrap"
URL_REMOTE_PATH_SRC="$URL_REMOTE_PATH_ROOT/src"

COLOR_GREEN="\033[0;32m"
COLOR_RED="\033[0;31m"
COLOR_NC="\033[0m"

PLAYBOOK="$1"

# --- DEFINE FUNCTIONS ---------------------------------------------------------

writeTask() {
	printf "\-\-> %s... " "$1"
}

writeInfo() {
	printf "[i] %s\n" "$1"
}

writeOk() {
	echo -e "${COLOR_GREEN}OK${COLOR_NC}"
}

writeFail() {
	echo -e "${COLOR_RED}FAIL${COLOR_NC}"
}

writeBanner() {
	printf "\-\-\- %s \-\-\-\n" "$1"
}

writeDone() {

	TIME_END=$(date +"%s")
	STR_TIME_END_PRETTY=$(date +"%H:%M:%S")

	TIME_ELAPSED=$((TIME_END - TIME_START))
	TIME_ELAPSED_MIN=$((TIME_ELAPSED / 60))
	TIME_ELAPSED_SEC=$((TIME_ELAPSED % 60))
	STR_TIME_ELAPSED_MIN=$(printf '%02d' "$TIME_ELAPSED_MIN")
	STR_TIME_ELAPSED_SEC=$(printf '%02d' "$TIME_ELAPSED_SEC")

	writeInfo "DONE! Finished at $STR_TIME_END_PRETTY (took $STR_TIME_ELAPSED_MIN:$STR_TIME_ELAPSED_SEC)"

}

writePlaybookStart() {
	echo ""
	writeBanner "STARTING PLAYBOOK: $PLAYBOOK"
	echo ""
	writeInfo "Temp path = $DIR_WORK"
	writeInfo "Started at $STR_TIME_START_PRETTY"
}

run() {

	writeTask "$1"

	shift

	if output=$("$@" 2>&1); then
		writeOk
	else
		writeFail
		echo "$output"
		exit 1
	fi

}

runAsUser() {

	writeTask "$1"
	user=$2

	shift 2

	if output=$(su "$user" -c 'exec "$@"' sh "$@" 2>&1); then
		writeOk
	else
		writeFail
		echo "$output"
		exit 1
	fi

}

replaceFileWithRemote() {

	file="$1"
	local_path="$2"
	remote_path="$3"
	prefix="$4"        # Optional

	prefix_part=""

	# If a prefix is provided, set prefix_part to [prefix + `--`]
	if [ -n "$prefix" ]; then
		prefix_part="$prefix--"
	fi

	writeTask "Replace $file with remote"

	fetch -q -o "$DIR_WORK/$file" "$remote_path/$prefix_part$file"

	if [ -e "$local_path/$file" ]; then
		mv "$local_path/$file" "$local_path/$file-$STR_TIMESTAMP"
	fi

	if cp -- "$DIR_WORK/$file" $local_path/; then
		writeOk
	else
		writeFail
		exit 1
	fi

}

directoryCreate() {

	writeTask "Create directory $1"

	# Safeguard against empty argument
	if [ -z "$1" ]; then
		writeFail
		echo "No argument provided"
		exit 1;
	fi

	# Create directory only if it does not exist
	if [ ! -d "$1" ]; then
		if mkdir -p -- "$1"; then
			writeOk
		else
			writeFail
			exit 1
		fi
	else
		writeOk
	fi

}

directoryDelete() {

	writeTask "Delete directory $1"

	# Safeguard against empty argument
	if [ -z "$1" ]; then
		writeFail
		echo "No argument provided"
		exit 1;
	fi

	# Delete the directory only if it exists
	if [ -d "$1" ]; then
		if rm -rf -- "$1"; then
			writeOk
		else
			writeFail
			exit 1
		fi
	else
		writeOk
	fi

}

generateKeySSH() {

	user=$1
	keytype=$2
	keyfile=$3
	keypassphrase=$4

	if [ -e "$keyfile" ]; then
		writeInfo "SSH key for $user already exists"
	else
		runAsUser "Generate SSH key for $user" "$user" ssh-keygen -t "$keytype" -f "$keyfile" -N "$keypassphrase"
	fi

	writeInfo "User $STR_USER_NAME SSH public key is:"
	cat "$FILEPATH_USER_SSH_PUBLIC_KEY"

}

ensureUserExists() {

	writeTask "Ensure user $1 exists"

	if ! pw usershow "$1" > /dev/null 2>&1; then
		writeFail
		exit 1
	fi

	writeOk

}

serviceStart() {

	writeTask "Start/restart service $1"

	if service "$1" status > /dev/null 2>&1; then
		action=restart
	else
		action=start
	fi

	if output=$(service "$1" "$action" 2>&1); then
		writeOk
	else
		writeFail
		printf '%s\n' "$output" >&2
		exit 1
	fi

}

# Write to stderr
die() {
	echo "$*" >&2
}

# Display command usage information
writeUsage() {
	die "Usage: $0 <playbook>"
	exit 1
}

# --- TODO LISTS ---------------------------------------------------------------

todo_base() {
	echo " - Set up SSH"
	echo " - Configure swap file"
	echo " - Set timezone"
	echo " - Set hostfile address"
	echo " - Create user account $STR_USER_NAME"
}

todo_user() {
	echo " - Add the SSH pubkey to user $STR_USER_NAME GitHub/Forgejo accounts"
}

todo_famp() {
	echo "MariaDB:"
	echo " - Run /usr/local/bin/mysql_secure_installation"
	echo " - Tune /usr/local/etc/mysql/conf.d/server.cnf"
	echo ""
	echo "Apache:"
	echo " - Create an actual virtualhost wwwroot directory"
	echo " - Add a virtualhost conf to /usr/local/etc/apache24/virtualhosts"
	echo " - Uncomment /usr/local/etc/apache24/httpd.conf : Include virtualhosts"
	echo " - Restart the apache24 service"
	echo ""
	echo "PHP:"
	echo " - Replace /usr/local/etc/php.ini with a production version, if desired."
	echo " - Tune /usr/local/etc/php-fpm.d/www.conf"
}

writeTodo() {

	echo ""
	echo "--- TODO ---"
	echo ""

	case "$PLAYBOOK" in
		base) todo_base;;
		user) todo_user;;
		famp) todo_famp;;
	esac

	echo ""

}

# --- CHECK FOR ERRORS ---------------------------------------------------------

# Require root
[ "$(id -u)" -eq 0 ] || {
    die "Must run as root"
    exit 1
}

# Require exact number of params
if [ "$#" -ne "$INT_EXPECTED_ARGS" ]; then
    writeUsage
    exit 1
fi

# --- PLAYBOOK DEFINITIONS -----------------------------------------------------

playbook_base() {

	run "Ensure pkg system is available" sh -c 'pkg -N > /dev/null 2>&1 || pkg bootstrap -y'

	run "Update system packages" pkg update -q

	run "Upgrade system packages" pkg upgrade -y -q

	packages='
		doas
		vim
		eza
		htop
		ncdu
		tmux
		lsblk
		rsync
		iperf
		git
		bash
		bash-completion
		p5-ack
	'

	set -- $packages
	run "Installing $PLAYBOOK packages" pkg install -y -q "$@"

	# Configure doas
	replaceFileWithRemote "doas.conf" "/usr/local/etc/" "$URL_REMOTE_PATH_SRC"

	# Initialize the locate DB
	run "Enable weekly updates to locate database" sysrc weekly_locate_enable="YES"
	run "Prime locate database" /etc/periodic/weekly/310.locate

	# Clean up some junk
	run "Cleanup cached packages" pkg clean -a -y
	directoryDelete /usr/lib/debug

}

playbook_user() {

	ensureUserExists "$STR_USER_NAME"

	# packages='
	# '

	# set -- $packages
	# run "Installing $PLAYBOOK packages" pkg install -y -q "$@"

	run "Change user $STR_USER_NAME shell to Bash" chsh -s /usr/local/bin/bash $STR_USER_NAME

	# Install dotfiles
	replaceFileWithRemote ".profile" "$DIR_USER_HOME" "$URL_REMOTE_PATH_SRC" "user"
	replaceFileWithRemote ".vimrc" "$DIR_USER_HOME" "$URL_REMOTE_PATH_SRC" "user"
	replaceFileWithRemote ".bashrc" "$DIR_USER_HOME" "$URL_REMOTE_PATH_SRC" "user"

	# Configure SSH authorized_keys
	replaceFileWithRemote "authorized_keys" "$DIR_USER_HOME/.ssh/" "$URL_REMOTE_PATH_SRC" "user"
	run "Set ownership of authorized_keys" chown $STR_USER_NAME:$STR_USER_NAME $DIR_USER_HOME/.ssh/authorized_keys
	run "Set permissions on authorized_keys" chmod 640 $DIR_USER_HOME/.ssh/authorized_keys

	run "Silence login" touch $DIR_USER_HOME/.hushlogin
	run "Set ownership of $DIR_USER_HOME/.hushlogin" chown $STR_USER_NAME:$STR_USER_NAME $DIR_USER_HOME/.hushlogin

	# Generate an SSH key
	generateKeySSH "$STR_USER_NAME" "$STR_SSH_KEY_TYPE" "$FILEPATH_USER_SSH_PRIVATE_KEY" ""

}

playbook_famp() {

	packages='
		mariadb118-server
		apache24
		php83
		php83-bcmath
		php83-ctype
		php83-curl
		php83-dom
		php83-exif
		php83-fileinfo
		php83-filter
		php83-gd
		php83-iconv
		php83-mbstring
		php83-mysqli
		php83-pdo
		php83-pdo_mysql
		php83-phar
		php83-session
		php83-simplexml
		php83-sodium
		php83-tokenizer
		php83-xml
		php83-xmlreader
		php83-xmlwriter
		php83-zip
		php83-zlib
	'

	set -- $packages
	run "Installing $PLAYBOOK packages" pkg install -y -q "$@"

	# --- MariaDB

	run "Enable MariaDB service" sysrc mysql_enable=YES

	serviceStart "mysql-server"

	# --- Apache

	replaceFileWithRemote "httpd.conf" "/usr/local/etc/apache24/" "$URL_REMOTE_PATH_SRC"

	directoryCreate /usr/local/etc/apache24/virtualhosts

	directoryCreate /srv/html
	run "Set permissions on /srv" chmod -R 775 /srv

	directoryCreate /var/log/apache
	run "Set ownership of /var/log/apache" doas chown root:wheel /var/log/apache
	run "Set permissions on /var/log/apache" doas chmod 755 /var/log/apache

	# Enable Apache later, after PHP is set up
	# run "Enable Apache service" sysrc apache24_enable=YES

	# Start Apache later, after PHP is set up
	# serviceStart "apache24"

	# --- PHP

	replaceFileWithRemote "php.ini" "/usr/local/etc/" "$URL_REMOTE_PATH_SRC" "php"
	replaceFileWithRemote "www.conf" "/usr/local/etc/php-fpm.d/" "$URL_REMOTE_PATH_SRC" "php"
	replaceFileWithRemote "index.php" "/usr/local/www/apache24/data/" "$URL_REMOTE_PATH_SRC" "apache"

	run "Enable Apache service" sysrc apache24_enable=YES
	run "Enable PHP-FPM service" sysrc php_fpm_enable=YES

	serviceStart "php_fpm"
	serviceStart "apache24"

}

# ------------------------------------------------------------------------------

case "$PLAYBOOK" in

	base) run_this_playbook="playbook_base" ;;
	user) run_this_playbook="playbook_user" ;;
	famp) run_this_playbook="playbook_famp" ;;

	*)
		die "Playbook '$PLAYBOOK' not defined"
		exit 1
	;;

esac

writePlaybookStart
"$run_this_playbook"
writeDone
writeTodo
