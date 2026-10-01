# Good Boy

Zero-dependency, native-FreeBSD bootstrapper in a *smol*, single sh script.

## Overview

*Good Boy* is an ultra-lightweight system provisioning single sh shell script for FreeBSD. It has a playbook concept that mimics Ansible, but runs without any external dependencies.

## Background

**Read more about *Good Boy* [on my blog](https://www.gaelanlloyd.com/blog/good-boy-zero-dependency-freebsd-bootstrapper/)**.

I built *Good Boy* because I wanted a tiny, zero-dependency bootstrapper for fresh FreeBSD installs, especially jails and other baseline systems that I'm frequently spinning up in my homelab.

I had written provisioning scripts before, but they were more complex than I wanted. I tried to keep things DRY, and so the script split all the functions across multiple files, and each playbook lived in its own file. Getting the script loaded onto the target machine required installing and configuring Git, cloning a repo, etc.

*Good Boy* is much simpler. It's one self-contained `sh` script with everything contained inside it, and it only uses the native FreeBSD shell and base system tools. Supporting source files can live in a remote location, and only the one script needs to be downloaded with `fetch` to kick off the bootstrap process.

This makes the script a little bigger, but it keeps the moving parts *smol*.

*Good Boy* is "partially idempotent" in a good-enough-for-me way. Some tasks are safe to rerun, others may overwrite or make destructive changes. Use with care. Teach him only the tricks you trust him to perform.

## Who's this tool for?

Anyone building VMs, provisioning jails, or working in lab environments that needs to quickly get their environment up and running.

*Good Boy* is great for:

- Solo devs
- Small teams
- Dev agencies
- Tinkerers

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
- Set up local user accounts for any userland playbooks

## Quick Start

> [!CAUTION]
> Please review and customize the included demo playbooks before running them on your system! *Good Boy* will run as `root` and will alter your system!

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

You can pass the prefix as an optional parameter in your playbooks. *Good Boy* will add the `--` to the filename automatically.

```shell
installFile file=".profile" local_path="$DIR_USER_HOME" prefix="user" owner="$STR_USER_NAME" group="$STR_USER_NAME" mode="644"
installFile file=".vimrc" local_path="$DIR_USER_HOME" prefix="user" owner="$STR_USER_NAME" group="$STR_USER_NAME" mode="644"
installFile file=".bashrc" local_path="$DIR_USER_HOME" prefix="user" owner="$STR_USER_NAME" group="$STR_USER_NAME" mode="644"
```

Some more complex setups may have multiple supporting files with the same name. The prefix here can also be used to differentiate those files.

```text
user-btorres--.bashrc
user-glaforge--.bashrc
user-lbrahms--.bashrc
```

And then in the playbook:

```shell
installFile file=".profile" local_path="/home/btorres" prefix="user-btorres" owner="btorres" group="btorres" mode="644"
installFile file=".profile" local_path="/home/glaforge" prefix="user-glaforge" owner="glaforge" group="glaforge" mode="644"
installFile file=".profile" local_path="/home/lbrahms" prefix="user-lbrahms" owner="lbrahms" group="lbrahms" mode="644"
```

## Running the script

```shell
fetch https://your-remote.com/good-boy.sh
chmod +x good-boy.sh
./good-boy.sh <playbook>
```

### Example Output

Here, we'll run the `base` playbook to initialize the baseline FreeBSD environment.

You'll see the tasks run, and then the helpful todo list printed at the end. What a *Good Boy!*

```shell
$ ./good-boy-repo.sh base

--- STARTING PLAYBOOK: base ---

[i] Temp path = /tmp/good-boy-20260930-210339.XTvYqN6s6N
[i] Started at 21:03:39
--> Update system packages... OK
--> Upgrade system packages... OK
--> Installing base packages... OK
--> Install /usr/local/etc/doas.conf from remote (root:wheel,0640)... OK
--> Enable weekly updates to locate database... OK
--> Prime locate database... OK
[i] DONE! Finished at 21:04:05 (took 00:26)

--- TODO ---

 - Set up SSH
 - Configure swap file
 - Set timezone
 - Set hostfile address
 - Create user account btorres
 ```

## FAQ

### Why doesn't *Good Boy* perform file-level manipulation? (To change settings within existing files, etc.)

Instead of performing line-by-line surgery on confs, finding and replacing target lines&hellip; Replace them with approved, final, full copies that you maintain in source control.

Someone on a random Reddit post mentioned that once, and it has really transformed how I work. It's improved my understanding of the confs I work with, and it's so much cleaner to just roll your own full confs.

Be sure to keep an eye on your confs over time. Check for upstream changes for features and defaults, and incorporate them as needed.

### Why doesn't *Good Boy* bootstrap the `pkg` system?

*Good Boy* used to&hellip; until I recently encountered [the famous version mismatch issue again](https://www.gaelanlloyd.com/blog/freebsd-fix-newer-freebsd-version-pkg-error/) when provisioning a newly-created jail.

Initially I started coding up a fix, intending to have *Good Boy* correct the issue&hellip; but that code started to become complex and edge-casey. I decided that the cleanest solution would be to have the operator bootstrap the `pkg` system manually. If there's a version mismatch then the system is in a bad state and requires some significant manual intervention. Those fixes are beyond the scope of this project.

## Built-in commands

- `run`
  - Run any arbitrary command.
- `runAsUser`
  - Run any arbitrary command as a particular user on the system.
- `installDir`
  - Uses `install(1)` to create paths and set ownership and permissions.
  - Owner, group, and mode permissions are required parameters to help prevent unanticipated headaches and unintentional security issues.
  - If you need to ensure the owner, group, and mode permissions for multiple levels of subfolders, use multiple `installDir()` lines.
- `installFile`
  - Uses `install(1)` to create files and set ownership and permissions.
  - Remote file name must be the same on the remote as the local file will be, other than the following exception.
  - Since some remote files may have similar names, or since these collections may contain many files, this command has an optional `prefix` argument that allows you to organize the remote conf files with a leading prefix (`user--.profile`, `user--.bashrc`, `vim--.vimrc`, `vim--yourcolorscheme`, etc.) *Good Boy* will add the `--` automatically, so just provide the prefix without it.
  - Owner, group, and mode permissions are required parameters to help prevent unanticipated headaches and unintentional security issues.
  - `remote_path` is optional. It defaults to `URL_REMOTE_PATH_ROOT`, but can be overridden.
- `directoryDelete`
- `ensureUserExists`
- `serviceStart`
  - Restarts a service if it's already running.
- `generateSSHKey`
  - Skips if key exists. Prints the new pubkey after.
