# Good Boy

Zero-dependency, native-FreeBSD bootstrapper in a *smol*, single sh script.

## Overview

*Good Boy* is an ultra-lightweight system provisioning single sh shell script for FreeBSD. It has a playbook concept that mimics Ansible, but runs without any external dependencies.

## Background

**Read more about Good Boy [on my blog](https://www.gaelanlloyd.com/blog/good-boy-zero-dependency-freebsd-bootstrapper/)**.

I built *Good Boy* because I wanted a tiny, zero-dependency bootstrapper for fresh FreeBSD installs, especially jails and other baseline systems that I'm frequently spinning up in my homelab.

I had written provisioning scripts before, but they were more complex than I wanted. I tried to keep things DRY, and so the script split all the functions across multiple files, and each playbook lived in its own file. Getting the script loaded onto the target machine required installing and configuring Git, cloning a repo, etc.

*Good Boy* is much simpler. It's one self-contained `sh` script with everything contained inside it, and it only uses the native FreeBSD shell and base system tools. Supporting source files can live in a remote location, and only the one script needs to be downloaded with `fetch` to kick off the bootstrap process.

This makes the script a little bigger, but it keeps the moving parts *smol*.

*Good Boy* is "partially idempotent" in a good-enough-for-me way. Some tasks are safe to rerun, others may overwrite or make destructive changes. Use with care. Teach him only the tricks you trust him to perform.

## Who's this tool for?

- Solo devs
- Small teams

*Good Boy* is not:

- Meant to be run blindly on fleets of machines, as not every command is truly idempotent.
- Able to do *everything* (the post-run todo list helps the operator remember to perform follow-up actions).

## Features

The internet is a big place, and I'm sure there's lots of similar tools out there&hellip; but I believe these features make *Good Boy* stand out from being just a simple shell script:

- Single-file bootstrapping script with zero dependencies
- Runs multiple playbooks
- Rapidly bootstraps environments
- Built-in functions with an easy-to-understand syntax for common tasks
- Idempotent (mostly!)
- Backs up any replaced files with timestamped archive copies
- Easy to audit and modify to suit your needs
- Fetch and place pre-built conf files from remote locations
- Sample playbooks included (base system, user creation, FAMP stack web server)
- Post-launch todo list reminders the sysadmin should do afterwards

## Requirements

Root or superuser access on a freshly-installed FreeBSD environment that has a working internet connection.

Do these tasks that can sometimes require complex interaction:
- Bootstrap the pkg system (via `pkg boostrap`)
- Set up local user accounts for any userland playbooks (`~/.bashrc`, etc.)

## Quick Start

> [!CAUTION]
> Please review and customize the included demo playbooks before running them on your system!

Steps to get started:

- Clone this repo
- Modify the `good-boy.sh` script
  - Update the globals (user name, report paths, etc.)
  - Adjust playbooks as necessary
  - Update the playbook todo lists with your personal post-run notes
- Upload the script and the supporting conf file subfolder to the remote location
  - Any network location accessible by the target machine will do. It could be a local FTP server, public FTP server, AWS S3, or any other service that `fetch` can retrieve files from.
- On the target machine:
  - Download the `good-boy.sh` script
  - Mark it executable
  - Use it to run the desired playbooks

## Creating supporting conf files

The supporting conf files will be stored in a subfolder beside the script and contain the approved, final copies of conf files that you want to install on the machine. For instance, `.rc` files, `.conf` files, and even files like `~/ssh/authorized_keys`.

Stubs for common supporting files are provided in this repo. Customize them and add others as needed.

### Naming

An optional **prefix** allows you to organize the supporting files.

```text
doas.conf
apache--httpd.conf
apache--index.php
php--php.ini
php--www.conf
user--.bashrc
user--.profile
user--.vimrc
user--authorized_keys
```

You can pass the prefix as an optional fourth parameter in your playbooks. *Good Boy* will add the `--` automatically.

```shell
# Fourth parameter showing prefix usage
replaceFileWithRemote ".profile" "$DIR_USER_HOME" "$URL_REMOTE_PATH_SRC" "user"
replaceFileWithRemote ".vimrc" "$DIR_USER_HOME" "$URL_REMOTE_PATH_SRC" "user"
replaceFileWithRemote ".bashrc" "$DIR_USER_HOME" "$URL_REMOTE_PATH_SRC" "user"
```

Some more complex setups may have multiple supporting files with the same name. The prefix here can also be used to differentiate those files.

```text
user-btorres--.bashrc
user-glaforge--.bashrc
user-lbrahms--.bashrc
```

## Running the script

```shell
fetch https://your-bucket.s3.amazonaws.com/good-boy.sh
chmod +x good-boy.sh
./good-boy.sh <playbook>
```

### Example Output

Here, we'll run the `base` playbook to initialize the baseline FreeBSD environment.

You'll see the tasks run, and then the helpful todo list printed at the end. What a *Good Boy!*

```shell
$ ./good-boy.sh base

--- STARTING PLAYBOOK: base ---

[i] Temp path = /tmp/tmp.ZRQirYlKnm
[i] Started at 16:02:46
--> Ensure pkg system is available... OK
--> Update system packages... OK
--> Upgrade system packages... OK
--> Installing base packages... OK
--> Replace doas.conf with remote... OK
--> Enable weekly updates to locate database... OK
--> Prime locate database... OK
--> Cleanup cached packages... OK
--> Delete directory /usr/lib/debug... OK
[i] DONE! Finished at 16:03:18 (took 00:32)

--- TODO ---

 - Set up SSH
 - /boot/loader.conf autoboot_delay
 - Configure swap file
 - Set timezone
 - Set host file address
 - Set regular user account
 ```

## Tips

- Instead of performing line-by-line surgery on confs, finding and replacing target lines&hellip; Replace them with approved, final, full copies that you control.
  - Someone on a random Reddit post mentioned that once, and it has really transformed how I work. It's improved my understanding of the confs I work with, and it's so much cleaner to just roll your own full confs.
  - Be sure to keep an eye on your confs over time. Check for upstream changes for features and defaults, and incorporate them as needed.

## Built-in commands

- `run`
- `runAsUser`
- `replaceFileWithRemote`
  - Remote file name must be the same on the remote as the local file will be, other than the following exception.
  - Since some remote files may have similar names, or since these collections may contain many files, this command has an optional `prefix` argument that allows you to organize the remote conf files with a leading prefix (`user--.profile`, `user--.bashrc`, `vim--.vimrc`, `vim--yourcolorscheme`, etc.) *Good Boy* will add the `--` automatically, so just provide the prefix without it.
- `directoryCreate`
- `directoryDelete`
- `ensureUserExists`
- `serviceStart`
  - Restarts a service if it's already running.
- `generateSSHKey`
  - Skips if key exists. Prints the new pubkey after.
