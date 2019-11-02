#!/usr/bin/env bash
#############################################################
#                                                           #
#       Privex's Tor Setup Tool                             #
#       (C) 2019 Privex Inc. (https://www.privex.io)        #
#       Source: https://github.com/Privex/tor-setup         #
#       Released under the GNU AGPL v3                      #
#                                                           #
#############################################################
#                                                           #
#  This file is a simple runner script designed to be       #
#  installed into /usr/bin/torsetup to allow tor-setup      #
#  to work systemwide.                                      #
#                                                           #
#############################################################

# For updates to work effectively, it's best that updates are ran BEFORE we launch 
# the tor-setup.sh text based interface.
# To avoid issues with variables leaking into tor-setup.sh, we run the updates in a subshell.
(
    source /usr/local/share/tor-setup/lib/updater.sh
    autoupdate_shellcore
    autoupdate_torsetup
)

bash /usr/local/share/tor-setup/tor-setup.sh
