# Privex's Tor Node Setup Tool

This tool allows for user friendly configuration of either a normal Tor relay node, or a Tor exit node.

**TorSetup** was designed to be used on our [Tor Friendly Sweden Servers](https://www.privex.io/), it
ensures that users configure their Tor node correctly, especially exit nodes.

See the [Screenshots](#screenshots) section if you want to see it in action, including a screenshot
of one of the generated HTML Tor exit notices.

**What it does:**

 - Asks the user for various information for generating configs / templates

    - Asks the user for a nickname
    - Asks the user if they want to configure a rate limit, and if so, guides the user on setting
      appropriate rate limits, with number validation.
    - Asks the user if they operate any other Tor relays / exits

        - If they do, it will ask for the fingerprints of their other nodes (excluding bridges),
          and explains how to find the fingerprints for each node

    - Automatically detects the external IPv4 + IPv6 address to correctly configure OutboundBindAddress

        - This also allows the setup tool to enable or disable IPv6 configuration options, depending on whether
          the server has IPv6 or not

    - Asks the user whether they want an exit node or not (with no meaning they get a normal relay)
    - Asks the user for the reverse DNS of their node, including printing out the current rDNS detected for their
      external IPs, and explains the importance of reverse DNS for exit nodes + how to setup rDNS
    - Asks the user for their operator name and contact info, with clear examples to ensure sensible
      configuration
    - Asks the user for their expected network speeds, allowing the speeds to be clearly displayed
      on the HTTP exit/relay notice page (DirPort).
    - Shows a summary of their configuration when they're done, and allows them to re-do individual
      questions if they need to correct something.

 - After the user is ready, TorSetup will then:

 - Generate a torrc file - on servers which have IPv6 this will be a fully IPv6 compatible config, enabling
   IPv6 relaying, as well as outbound IPv6 if they're an exit

 - Generates a HTML exit notice (DirPort index file) based on the details the user entered

 - Configures nginx to display the HTML exit notice on port 80 (IPv4 + v6), and correctly proxies
   Tor directory queries to the Tor node itself.

 - Once all configs are in place, it will then enable / restart both Tor and Nginx
      

**Table of Contents**

 - [Requirements](#requirements)
 - [Usage / Install](#usage)
    - [Install Dependencies](#install-dependencies)
    - [Install TorSetup from Github](#install-torsetup-from-github)
 - [Screenshots](#screenshots)
 - [Automated installations](#automated-installations)
 - [License](#license)
 - [Contributing](#contributing)
 - [Thanks for reading!](#thanks-for-reading)

# Requirements

 - Tested on Ubuntu 18.04 - however other debian based systems should work too
 - Python (even 2.7 is fine) - used for replacing placeholders in the template files when generating configurations
 - Bash (generally pre-installed on most Unix/Linux systems)
 - Git
 - Curl
 - Tor (if not installed, the script will automatically attempt to `apt-get install` it)
 - Nginx (if not installed, the script will automatically attempt to `apt-get install` it)
 - GNU core utilities, mainly `grep`, `sed`, and `awk`
     - If using on a BSD system such as macOS or FreeBSD, it's fine if they're installed as `ggrep`, `gsed` and `gawk`.
       The script uses [GNUSafe](https://github.com/Privex/shell-core/blob/master/lib/000_gnusafe.sh), a component of our
       Bash library [Privex ShellCore](https://github.com/Privex/shell-core) which will automatically set up aliases
       for the GNU utilities on BSD systems, ensuring the script works fine regardless of whether GNU grep is installed 
       at `grep` or `ggrep`

# Usage

### Install dependencies

Install `git`, `curl`, `python` and `nginx`. 

Import TorProject's signing key and add their repository, as it's updated more often / faster than the `tor` package
included in most distributions repos.

Then install Tor, and the TorProject's keyring package (so they can update the signing key automatically when you update Tor).

```bash
# Install git, curl, python and nginx
apt install -y git curl python nginx

# Add TorProject's package signing key ( https://2019.www.torproject.org/docs/debian.html.en )
curl https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --import
gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -
# Add the official TorProject apt repository, which usually has a more recent 
# version of Tor than most distribution's default repos
add-apt-repository -s 'https://deb.torproject.org/torproject.org main'
apt update -y
# Install Tor, and TorProject's keyring package (allows you to receive updated 
# TorProject signing keys when you run apt upgrade)
apt install -y tor deb.torproject.org-keyring
```

### Install TorSetup from Github

Simply clone the repo and run `tor-setup.sh` - it will guide you through the whole process of setting up a Tor relay/exit,
and automatically generate a Tor config, an nginx config, and a customised exit notice page which will be displayed when
someone browses to your node's port 80 (`i.e. http://your-node-ip`).

```bash
git clone https://github.com/Privex/tor-setup.git
cd tor-setup

./tor-setup.sh
```

Installing systemwide:

```bash
git clone https://github.com/Privex/tor-setup.git /usr/local/share/tor-setup
chmod -R 755 /usr/local/share/tor-setup
chmod +x /usr/local/share/tor-setup/*.sh

install /usr/local/share/tor-setup/cmd.sh /usr/bin/torsetup
```

# Screenshots

**Terminal user interface**

![](https://cdn.privex.io/github/tor-setup/screenshot-1.png)
![](https://cdn.privex.io/github/tor-setup/screenshot-2.png)
![](https://cdn.privex.io/github/tor-setup/screenshot-3.png)
![](https://cdn.privex.io/github/tor-setup/screenshot-4.png)

**Example of automatically generated Tor Exit notice**

![](https://cdn.privex.io/github/tor-setup/screenshot-5.png)


# Automated installations

This tool supports automated Tor relay/exit node installations using environment variables.

See the example automated installation file at `example-auto.env` to see how to write your own. A small explanation for each of the `AUTO_`
variables is available at the top of `tor-setup.sh`

Running automated installations:

```bash
# Option 1. Pass the environment file as the first argument (can also contain any bash code)
./tor-setup.sh example-auto.env

# Option 2. Source the environment file then run tor-setup (not recommended if you have complex bash code inside)
source example-auto.env
./tor-setup.sh

# Option 3. Manually export AUTO_ variables in your shell, then run tor-setup
export AUTO_NICKNAME="MyExampleNode" AUTO_USE_FAMILY=n AUTO_IS_EXIT=n AUTO_RDNS="mynode.example.com"
./tor-setup.sh

# Option 3. Enter the AUTO_ variables in-line with the tor-setup command
AUTO_NICKNAME="MyExampleNode" AUTO_USE_FAMILY=n ./tor-setup.sh
```

For a fully automated installation, you must set all main `AUTO_` variables. You do not have to set dependent `AUTO_` variables
if their related yes/no setting is disabled (set to `n`).

For example:

 - If `AUTO_USE_LIMIT` is set to `n` - then you do not need to set `AUTO_RATE_MBPS` or `AUTO_BURST_MBPS`.
 - If `AUTO_USE_LIMIT` was set to `y`, then if you do not fill out `AUTO_RATE_MBPS` / `AUTO_BURST_MBPS` then **the script will simply exit**
   **with a non-zero exit code** once it gets to that section of the setup.

The only exception is `AUTO_PKG_INSTALL` - this option generally does not need to be set.

When the script starts up, it runs dependency checks for `dig`, `nginx` and `tor`. If they aren't installed, it will attempt to install them via `apt-get`

Setting `AUTO_PKG_INSTALL=y` disables this automated dependency check / installation. Some examples of where you may want to use this setting:

 - A non-debian based system (if it can't find the binaries, it will try to `apt` install them, which will most likely cause the script to abort).
 - An unpriviliged user (i.e. without sudo, or a sudo config that needs manual password entry)
 - A setup where the binaries `dig`, `nginx` and/or `tor` aren't normally in the `PATH`
    - `dig` is only used in when `AUTO_RDNS` isn't set. It's used to show the user the existing reverse DNS of their public IPv4 / IPv6 address
    - `nginx` and `tor` aren't actually used in the script itself, but the script will attempt to install them if it can't detect them, because
      TorSetup obviously configures Tor, and also installs an nginx configuration file for serving the exit notice.

# License

```
+===================================================+
|                 © 2019 Privex Inc.                |
|               https://www.privex.io               |
+===================================================+
|                                                   |
|        Privex Tor Setup Tool                      |
|                                                   |
|        Core Developer(s):                         |
|                                                   |
|          (+)  Chris (@someguy123) [Privex]        |
|                                                   |
+===================================================+

Privex Tor Setup Tool - A tool written in bash to make setting up a Tor relay or exit user friendly.
Copyright (C) 2019    Privex Inc. (https://www.privex.io)


    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

```

# Contributing

We're very happy to accept pull requests, and work on any issues reported to us. 

Here's some important information:

**Reporting Issues:**

 - Various bash functions such as `msg`, `gnusafe`, `pkg_not_found` and the error handling (tracebacks with line numbers and things) are not part of this Git repo.
   If you can't find the source for a certain function, it's probably part of our [Privex ShellCore](https://github.com/Privex/shell-core) library, and you should
   report the issue there.
 - For bug reports, you should include the following information:
     - Git revision number that the issue was tested on - `git log -n1`
     - Your bash version - `bash --version`
     - Your operating system and OS version (e.g. Ubuntu 18.04, Debian 7)
 - For feature requests / changes
     - Please avoid suggestions that require new dependencies. This tool is designed to be highly portable so that it can be installed across many servers with minimal effort.
     - Clearly explain the feature/change that you would like to be added
     - Explain why the feature/change would be useful to us, or other users of the tool
     - Be aware that features/changes that are complicated to add, or we simply find un-necessary for our internal use of the tool may not be added (but we may accept PRs)
    
**Pull Requests:**

 - We'll happily accept PRs that only add code comments or README changes
 - Use 4 spaces, not tabs when contributing to the code
 - You can use Bash 4.4+ features such as associative arrays (dictionaries)
    - Features that require a Bash version that has not yet been released for the latest stable release
      of Ubuntu Server LTS (at this time, Ubuntu 18.04 Bionic) will not be accepted. 
 - Clearly explain the purpose of your pull request in the title and description
     - What changes have you made?
     - Why have you made these changes?
 - Please make sure that code contributions are appropriately commented - we won't accept changes that involve uncommented, highly terse one-liners.

**Legal Disclaimer for Contributions**

Nobody wants to read a long document filled with legal text, so we've summed up the important parts here.

If you contribute content that you've created/own to projects that are created/owned by Privex, such as code or 
documentation, then you might automatically grant us unrestricted usage of your content, regardless of the open source 
license that applies to our project.

If you don't want to grant us unlimited usage of your content, you should make sure to place your content
in a separate file, making sure that the license of your content is clearly displayed at the start of the file 
(e.g. code comments), or inside of it's containing folder (e.g. a file named LICENSE). 

You should let us know in your pull request or issue that you've included files which are licensed
separately, so that we can make sure there's no license conflicts that might stop us being able
to accept your contribution.

If you'd rather read the whole legal text, it should be included as `privex_contribution_agreement.txt`.

# Thanks for reading!

**If this project has helped you, consider [grabbing a VPS or Dedicated Server from Privex](https://www.privex.io) - prices start at as little as US$8/mo (we take cryptocurrency!)**