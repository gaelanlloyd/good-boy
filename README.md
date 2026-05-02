# Good Boy

Zero-dependency, native-FreeBSD bootstrapper in a *smol*, single sh script.

## Overview

*Good Boy* is an ultra-lightweight system provisioning single sh shell script for FreeBSD. It has a playbook concept that mimics Ansible, but runs without any external dependencies.

## Background

**Read more about Good Boy [on my blog](https://www.gaelanlloyd.com/blog/good-boy-zero-dependency-freebsd-bootstrapper/)**.

I built *Good Boy* because I wanted a tiny, zero-dependency bootstrapper for fresh FreeBSD installs, especially jails and other baseline systems that I'm frequently spinning up in my homelab.

I had written provisioning scripts before, but they were more complex than I wanted. In the name of being DRY, they were split across multiple function files, with each playbook living in its own file. That meant everything had to live in a Git repo, and a fresh system needed a bunch of setup before anything useful could happen: install Git, generate SSH keys, clone the repo, and only then start bootstrapping.

*Good Boy* takes the opposite approach. It is one self-contained `sh` script with all playbooks inside it, using only the native FreeBSD shell and base system tools. Supporting source files can live somewhere remote, but only one script needs to be downloaded to kick off the bootstrap process.

This makes the script a little bigger, but keeps the moving parts *smol*.

The goal is not perfect configuration management. *Good Boy* is only "partially idempotent" in a good-enough-for-me way. Some tasks are safe to rerun, others may overwrite or change things destructively. Use with care, and teach him only the tricks you trust him to perform.

## Who's this tool for?

- Solo devs
- Small teams

*Good Boy* is not:

- Meant to be run blindly on fleets of machines, as not every command is truly idempotent.
- Able to do *everything*. Hence the addition of the post-run todo list.

The point of *Good Boy* is to get the bulk of the work done for you, the heavy lifting... Leaving you free time to spend doing the fine-tuning required to get your system into tip-top shape.

## Features

I'm sure there's lots of similar tools out there, but I believe these features make *Good Boy* truly stand out from just a simple shell script:

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

- Root access on a freshly-installed FreeBSD environment
- Network access

## Quick Start

You'll want to begin by:

- Cloning this repo
- Modifying the `good-boy.sh` script
  - Add and adjust playbooks as necessary
  - Add supporting files to an accessible remote location
- Copy the script up to the remote location
- Then, download it to the target machine, mark it executable, and run the desired playbook(s).

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

- Instead of performing line-by-line surgery on confs, finding and replacing target lines... Replace them with approved, final, full copies that you control.
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
- `serviceStart`
  - Restarts a service if it's already running.
- `generateSSHKey`
  - Sskips if key exists, always prints pubkey after.
