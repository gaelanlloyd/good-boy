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

DIR_WORK=$(mktemp -d -t "good-boy-$STR_TIMESTAMP")

STR_USER_NAME="btorres"
DIR_USER_HOME="/home/btorres"

STR_SSH_KEY_TYPE="ed25519"
# STR_SSH_KEY_TYPE="rsa"
FILEPATH_USER_SSH="$DIR_USER_HOME/.ssh"
FILEPATH_USER_SSH_PRIVATE_KEY="$FILEPATH_USER_SSH/id_rsa"
FILEPATH_USER_SSH_PUBLIC_KEY="$FILEPATH_USER_SSH/id_rsa.pub"

URL_REMOTE_PATH_ROOT="https://example.com/bootstrap"
URL_REMOTE_PATH_SRC="$URL_REMOTE_PATH_ROOT/src"

COLOR_GREEN="\033[0;32m"
COLOR_RED="\033[0;31m"
COLOR_NC="\033[0m"

PLAYBOOK="$1"

# --- DEFINE FUNCTIONS ---------------------------------------------------------

write() {
    printf '%s\n' "$1"
}

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
    write
    writeBanner "STARTING PLAYBOOK: $PLAYBOOK"
    write
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
        write "$output"
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
        write "$output"
        exit 1
    fi

}

installFile() {

    # Usage:
    # installFile \
    #   file=NAME \
    #   local_path=DIR\[remote_path=URL] \
    #   owner=OWN \
    #   group=GRP \
    #   mode=MODE \
    #   [prefix=STR] \
    #
    # local_path,
    # remote_path:
    #   - Trailing slashes are optional and will be stripped if passed.
    #
    # owner,
    # group,
    # mode:
    #   - Required to reduce confusion and prevent accidental security issues.

    # Define vars as local
    local file local_path remote_path prefix owner group mode

    # Set defaults
    file=""
    local_path=""
    remote_path=$URL_REMOTE_PATH_SRC
    prefix=""
    owner=""
    group=""
    mode=""

    # Iterate over args
    for arg in "$@"; do
        case "$arg" in
            file=*)         file=${arg#file=} ;;
            local_path=*)   local_path=${arg#local_path=} ;;
            remote_path=*)  remote_path=${arg#remote_path=} ;;
            owner=*)        owner=${arg#owner=} ;;
            group=*)        group=${arg#group=} ;;
            mode=*)         mode=${arg#mode=} ;;
            prefix=*)       prefix=${arg#prefix=} ;;
            *) printf 'installFile: unknown parameter: %s\n' "$arg" >&2
               return 2 ;;
        esac
    done

    # Check for errors

    [ -n "$file" ] || { echo "installFile: [file] is required" >&2; return 2; }
    [ -n "$local_path" ] || { echo "installFile: [local_path] is required" >&2; return 2; }
    [ -n "$remote_path" ] || { echo "installFile: [remote_path] is required" >&2; return 2; }
    [ -n "$owner" ] || { echo "installFile: [owner] is required" >&2; return 2; }
    [ -n "$group" ] || { echo "installFile: [group] is required" >&2; return 2; }
    [ -n "$mode" ] || { echo "installFile: [mode] is required" >&2; return 2; }

    # Strip trailing slashes if necessary
    local_path=${local_path%/}
    remote_path=${remote_path%/}

    writeTask "Install $local_path/$file from remote ($owner:$group,$mode)"

    # If a prefix is provided, set prefix_part to [prefix + `--`]
    if [ -n "$prefix" ]; then
        prefix="$prefix--"
    fi

    # Download the remote file to the temp folder
    if ! fetch -q -o "$DIR_WORK/$file" "$remote_path/$prefix$file"; then
        writeFail
        exit 1
    fi

    # If the target file exists, move it out of the way
    if [ -e "$local_path/$file" ]; then
        mv "$local_path/$file" "$local_path/$file-$STR_TIMESTAMP"
    fi

    if install -o "$owner" \
        -g "$group" \
        -m "$mode" \
        "$DIR_WORK/$file" \
        "$local_path/$file"; then
        writeOk
    else
        writeFail
        exit 1
    fi

}

installDir() {

    # Usage:
    # installDir \
    #   path=NAME \
    #   owner=OWN \
    #   group=GRP \
    #   mode=MODE \
    #
    # owner,
    # group,
    # mode:
    #   - Required to reduce confusion and prevent accidental security issues.

    # Define vars as local
    local path owner group mode

    # Set defaults
    path=""
    owner=""
    group=""
    mode=""

    # Iterate over args
    for arg in "$@"; do
        case "$arg" in
            path=*)         path=${arg#path=} ;;
            owner=*)        owner=${arg#owner=} ;;
            group=*)        group=${arg#group=} ;;
            mode=*)         mode=${arg#mode=} ;;
            *) printf 'installDir: unknown parameter: %s\n' "$arg" >&2
               return 2 ;;
        esac
    done

    # Check for errors

    [ -n "$path" ] || { echo "installDir: [path] is required" >&2; return 2; }
    [ -n "$owner" ] || { echo "installDir: [owner] is required" >&2; return 2; }
    [ -n "$group" ] || { echo "installDir: [group] is required" >&2; return 2; }
    [ -n "$mode" ] || { echo "installDir: [mode] is required" >&2; return 2; }

    writeTask "Create directory $path ($owner:$group,$mode)"

    if install -d \
        -o "$owner" \
        -g "$group" \
        -m "$mode" \
        "$path"; then
        writeOk
    else
        writeFail
        exit 1
    fi

}

directoryDelete() {

    writeTask "Delete directory $1"

    # Safeguard against empty argument
    if [ -z "$1" ]; then
        writeFail
        write "No argument provided"
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
    write " - Set up SSH"
    write " - Configure swap file"
    write " - Set timezone"
    write " - Set hostfile address"
    write " - Create user account $STR_USER_NAME"
}

todo_user() {
    write " - Add the SSH pubkey to user $STR_USER_NAME GitHub/Codeberg accounts"
}

todo_famp() {
    write "MariaDB:"
    write " - Run /usr/local/bin/mysql_secure_installation"
    write " - Tune /usr/local/etc/mysql/conf.d/server.cnf"
    write ""
    write "Apache:"
    write " - Create an actual virtualhost wwwroot directory"
    write " - Add a virtualhost conf to /usr/local/etc/apache24/virtualhosts"
    write " - Uncomment /usr/local/etc/apache24/httpd.conf : Include virtualhosts"
    write " - Restart the apache24 service"
    write ""
    write "PHP:"
    write " - Replace /usr/local/etc/php.ini with a production version, if desired."
    write " - Tune /usr/local/etc/php-fpm.d/www.conf"
}

writeTodo() {

    write ""
    write "--- TODO ---"
    write ""

    case "$PLAYBOOK" in
        base) todo_base;;
        user) todo_user;;
        famp) todo_famp;;
    esac

    write ""

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

# Require the pkg system be bootstrapped first
# pkg system version mismatches in jails can be complicated to solve, don't try
if ! pkg -N >/dev/null 2>&1; then
    die "Bootstrap the pkg system first."
    exit 1
fi

# --- PLAYBOOK DEFINITIONS -----------------------------------------------------

playbook_base() {

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
    installFile file="doas.conf" local_path="/usr/local/etc" owner="root" group="wheel" mode="0640"

    # Initialize the locate DB
    run "Enable weekly updates to locate database" sysrc weekly_locate_enable="YES"
    run "Prime locate database" /etc/periodic/weekly/310.locate

    # Clean up some junk
    # run "Cleanup cached packages" pkg clean -a -y
    # directoryDelete /usr/lib/debug

}

playbook_user() {

    ensureUserExists "$STR_USER_NAME"

    # packages='
    # '

    # set -- $packages
    # run "Installing $PLAYBOOK packages" pkg install -y -q "$@"

    run "Change user $STR_USER_NAME shell to Bash" chsh -s /usr/local/bin/bash $STR_USER_NAME

    # Install dotfiles
    installFile file=".profile" local_path="$DIR_USER_HOME" prefix="user" owner="$STR_USER_NAME" group="$STR_USER_NAME" mode="644"
    installFile file=".vimrc" local_path="$DIR_USER_HOME" prefix="user" owner="$STR_USER_NAME" group="$STR_USER_NAME" mode="644"
    installFile file=".bashrc" local_path="$DIR_USER_HOME" prefix="user" owner="$STR_USER_NAME" group="$STR_USER_NAME" mode="644"

    # Configure SSH authorized_keys
    installDir path="$DIR_USER_SSH" owner="$STR_USER_NAME" group="$STR_USER_NAME" mode="700"
    installFile file="authorized_keys" local_path="$DIR_USER_SSH" prefix="user" owner="$STR_USER_NAME" group="$STR_USER_NAME" mode="600"

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

    installFile file="httpd.conf" local_path="/usr/local/etc/apache24/" prefix="apache" owner="root" group="wheel" mode="644"

    installDir path="/var/log/apache" owner="root" group="wheel" mode="775"

    installDir path="/usr/local/etc/apache24/virtualhosts" owner="root" group="wheel" mode="755"

    installDir path="/srv" owner="root" group="wheel" mode="775"
    installDir path="/srv/sites" owner="root" group="wheel" mode="775"
    installDir path="/srv/sites/www" owner="www" group="www" mode="755"

    # --- PHP

    installFile file="php.ini" local_path="/usr/local/etc/" prefix="php" owner="root" group="wheel" mode="644"
    installFile file="www.conf" local_path="/usr/local/etc/php-fpm.d/" prefix="php" owner="root" group="wheel" mode="644"
    installFile file="index.php" local_path="/usr/local/www/apache24/data/" prefix="apache" owner="root" group="wheel" mode="644"

    # --- Enable and start services

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
