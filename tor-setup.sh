#!/usr/bin/env bash
#############################################################################################################################
#
#       Privex's Tor Setup Tool
#       (C) 2019 Privex Inc. (https://www.privex.io)
#       Source: https://github.com/Privex/tor-setup
#       Released under the GNU AGPL v3
#
#############################################################################################################################
# Automatic configuration variables:
#
#     AUTO_PKG_INSTALL      (y/n) if 'y' then functions.install_tor_deps will be disabled (skip dependency detection / auto-install)
#     AUTO_SKIP_SUMMARY     (y/n) if 'y' then the question 'Does everything above look okay?' at the end will be skipped
#     AUTO_RESTART_SERVICES (y/n) (DEFAULT is 'y') Set to 'n' to disable automatically restarting Tor/Nginx after setup.
#     AUTO_NICKNAME         (string: nickname)
#
#     AUTO_USE_LIMIT        (y/n)
#     AUTO_RATE_MBPS        (integer) (required if AUTO_USE_LIMIT=='y')
#     AUTO_BURST_MBPS       (integer) (required if AUTO_USE_LIMIT=='y')
#
#     AUTO_USE_FAMILY       (y/n)
#     AUTO_FINGERPRINTS     (string: space sep fingerprints) (required if AUTO_USE_FAMILY=='y')
#
#     AUTO_IP_NO_PROMPT     (y/n) If set to 'y', will raise a non-zero exit code if we 
#                           can't detect IPv4, but failed IPv6 address will just quietly be ignored.
#
#     AUTO_IS_EXIT          (y/n)  y = exit node, n = relay node
#     AUTO_REDUCED_EXIT     (y/n)  y = use reduced exit policy, n = allow everything exit policy (defaults to y if not set)
#
#     AUTO_RDNS             (string: reverse DNS domain to use)
#     AUTO_NODE_OPERATOR    (string: operator name / contact info)
# 
#     AUTO_HAS_DOMAIN       (y/n)
#     AUTO_DOMAIN           (string: domain to use) (required if AUTO_HAS_DOMAIN=='y')
#
#     AUTO_NETWORK_SPEED    (string: advertised network speed on dirport HTML tor notice)
# 
# 
#############################################################################################################################


# Error handling function for ShellCore
_sc_fail() { >&2 echo "Failed to load or install Privex ShellCore..." && exit 1; }
# If `load.sh` isn't found in the user install / global install, then download and run the auto-installer from Privex's CDN.
[[ -f "${HOME}/.pv-shcore/load.sh" ]] || [[ -f "/usr/local/share/pv-shcore/load.sh" ]] || \
    { curl -fsS https://cdn.privex.io/github/shell-core/install.sh | bash >/dev/null; } || _sc_fail
# Attempt to load the local install of ShellCore first, then fallback to global install if it's not found.
[[ -d "${HOME}/.pv-shcore" ]] && source "${HOME}/.pv-shcore/load.sh" || source "/usr/local/share/pv-shcore/load.sh" || _sc_fail
# Quietly run ShellCore auto-updater
autoupdate_shellcore

if (($#>0)); then
    msg green "Auto-install file '$1' was passed."
    if [[ -f "$1" ]]; then
        msg green "Loading auto-install variables from passed filename."
        source "$1"
    else
        >&2 msg bold red " [!!!] ERROR: File $1 does not exist or we don't have permission to open it."
        exit 1
    fi
fi

_LN="======================================================================================================================="

# directory where the script is located, so we can source files regardless of where PWD is
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TORSETUP_DIR="$DIR"
TORSETUP_VERSION=$(git describe --tags)
TS_LIB_DIR="${TORSETUP_DIR}/lib"

: ${TPLDIR="${DIR}/templates"}                           # Templates folder containing torrc files, exit notice etc.
: ${BASE_TORRC="${TPLDIR}/base.torrc"}                   # Location of the template TORRC file for generating $TORRC_FILE
: ${EXIT_TORRC="${TPLDIR}/exit.torrc"}                   # Location of template TORRC file containing ExitPolicy
: ${HEADER_TORRC="${TPLDIR}/header.torrc"}               # Location of template TORRC header (placed at start of torrc before content)
: ${FOOTER_TORRC="${TPLDIR}/footer.torrc"}               # Location of template TORRC footer (placed at end of torrc after content)
: ${TORRC_FILE='/etc/tor/torrc'}                         # Where will we output the final generated torrc file to?
: ${TORNOTICE_FILE="${TPLDIR}/exitnotice.html"}          # Location of the template HTML for the exit/relay node notice
: ${TORNOTICE_OUTPUT='/var/www/html/tor/index.html'}     # Where will we output the final HTML tor exit notice to?
: ${BASE_NGINX="${TPLDIR}/nginx-default.conf"}           # Nginx configuration file to copy
: ${OUT_NGINX="/etc/nginx/sites-enabled/default"}        # Destination file to copy nginx config to
: ${TOR_DEBUG=0}                                         # Set to 1 to enable debugging messages

source "${SG_DIR}/lib/000_gnusafe.sh" || { >&2 msg bold red "CRITICAL ERROR: Could not load GnuSafe file at '${SG_DIR}/lib/000_gnusafe.sh' - Exiting!" && exit 1; }

gnusafe || exit 1

source "${TS_LIB_DIR}/questions.sh" || { 
    >&2 echo "${BOLD}${RED}[tor-setup.sh] CRITICAL ERROR: Could not load question functions at '${TS_LIB_DIR}/questions.sh' - Exiting!${RESET}"
    exit 1
}
[ ! -z ${TORSETUP_FUNCS_LOADED+x} ] || source "${TS_LIB_DIR}/functions.sh" || { 
    >&2 echo "${BOLD}${RED}[tor-setup.sh] CRITICAL ERROR: Could not load functions file at '${TS_LIB_DIR}/functions.sh' - Exiting!${RESET}"
    exit 1
}
[ ! -z ${TORSETUP_UPDATER_LOADED+x} ] || source "${TS_LIB_DIR}/updater.sh" || { 
    >&2 echo "${BOLD}${RED}[tor-setup.sh] CRITICAL ERROR: Could not load functions file at '${TS_LIB_DIR}/functions.sh' - Exiting!${RESET}"
    exit 1
}

source "${SG_DIR}/base/trap.bash" || { >&2 msg bold red "CRITICAL ERROR: Could not load error handler script at '${SG_DIR}/base/trap.bash' - Exiting!" && exit 1; }

# source "${DIR}/functions.sh" || { >&2 msg bold red "CRITICAL ERROR: Could not load functions file at '${DIR}/functions.sh' - Exiting!" && exit 1; }




msg "$_LN\n"

msg green "████████╗ ██████╗ ██████╗         ███╗   ██╗ ██████╗ ██████╗ ███████╗        ███████╗███████╗████████╗██╗   ██╗██████╗ ";
msg green "╚══██╔══╝██╔═══██╗██╔══██╗        ████╗  ██║██╔═══██╗██╔══██╗██╔════╝        ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗";
msg green "   ██║   ██║   ██║██████╔╝        ██╔██╗ ██║██║   ██║██║  ██║█████╗          ███████╗█████╗     ██║   ██║   ██║██████╔╝";
msg green "   ██║   ██║   ██║██╔══██╗        ██║╚██╗██║██║   ██║██║  ██║██╔══╝          ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ ";
msg green "   ██║   ╚██████╔╝██║  ██║        ██║ ╚████║╚██████╔╝██████╔╝███████╗        ███████║███████╗   ██║   ╚██████╔╝██║     ";
msg green "   ╚═╝    ╚═════╝ ╚═╝  ╚═╝        ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝        ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     ";
msg green "                                                                                                                       ";

msg "$_LN\n"
msg bold green "Welcome to Privex's Tor Setup Utility\n"
msg bold yellow "Libraries / Packages:\n"
msg bold cyan "\tPrivex ShellCore\n\t\t${BOLD}Version:${RESET} $S_CORE_VER\n\t\t${CYAN}${BOLD}Installed at:${RESET} $SG_DIR\n"
msg bold yellow "Configuration:\n"
msg bold cyan "\tBase Torrc:\t\t\t${RESET} $BASE_TORRC"
msg bold cyan "\tExit Policy:\t\t\t${RESET} $EXIT_TORRC"
msg bold cyan "\tTor Notice HTML Template:\t${RESET} $TORNOTICE_FILE\n"
msg bold cyan "\tOutputting to Torrc:\t\t${RESET} $TORRC_FILE"
msg bold cyan "\tOutputting Tor Notice to:\t${RESET} $TORNOTICE_OUTPUT"
msg "\n$_LN\n"

TOR_NICKNAME=''

TOR_USE_FAMILY="n"                    # Add a MyFamily directive with other relays/exits operated by the same user (y/n)
TOR_FINGERPRINTS=''                   # Other relay/exit fingerprints, separated by spaces

TOR_IS_EXIT="n"                       # Is this node supposed to be an exit node? (y/n)
TOR_REDUCED_EXIT="n"                  # If yes (y), will use the reduced exit policy in exit.torrc - otherwise (n) will allow all exit traffic

TOR_RDNS='n/a'                        # The server's reverse DNS, or planned rDNS - for display on the HTML tor notice.
TOR_NODE_OPERATOR='Unknown'           # Name / contact details of the node operator

TOR_HAS_DOMAIN='n'                    # Does the user have a domain pointing at this tor node?
TOR_DOMAIN=''                         # If TOR_HAS_DOMAIN is yes, then this contains the domain to use.
TOR_NETWORK_SPEED=''                  # Network speed (for display on directory HTML notice)

TOR_USE_LIMIT="n"                     # Enable network rate limiting for this node (y/n)
TOR_RATE_MBPS='' TOR_BURST_MBPS=''    # Rate limit / Burst limit for the node in megabits per second

HAS_IP4='n'  HAS_IP6='n'              # Whether or not this node has IPv4 / IPv6 (y/n)
IPV4_ADDRESS='' IPV6_ADDRESS=''       # If HAS_IP4 / 6 is yes, these store the server's primary public IPv4 / IPv6 address.

autoupdate_torsetup

install_tor_deps

msg yellow "To set up your Tor node, we're going to ask you a few questions"
msg yellow "Once we're done, we'll update your torrc config, and start your Tor node"

msg "\n$_LN\n"
######################################
# Ask user for the Tor node nickname #
######################################
if [ -z ${AUTO_NICKNAME+x} ]; then
    q_nickname
else
    msg bold green " [+++] Using AUTO_NICKNAME for nickname: $AUTO_NICKNAME"
    TOR_NICKNAME="$AUTO_NICKNAME"
fi
msg "\n$_LN\n"

#################################################
# Ask user if they want a rate limit.           #
# If so, configure the Rate Limit + Burst Limit #
#################################################

if [ -z ${AUTO_USE_LIMIT+x} ]; then
    q_rate_limit
else
    if [[ "$AUTO_USE_LIMIT" == "y" ]] && { [ -z ${AUTO_RATE_MBPS+x} ] || [ -z ${AUTO_BURST_MBPS+x} ]; }; then
        >&2 msg bold red "ERROR: AUTO_USE_LIMIT is set to 'y', but AUTO_RATE_MBPS or AUTO_BURST_MBPS are not set!"
        >&2 msg bold "To avoid hanging any shell scripts using this, exiting with non-zero status!"
        exit 1
    fi
    msg bold green " [+++] Using AUTO_USE_LIMIT for rate limit enablement: $AUTO_USE_LIMIT"
    TOR_USE_LIMIT="$AUTO_USE_LIMIT"
    
    [[ "$AUTO_USE_LIMIT" == "y" ]] && \
        msg green " [+] Rate limit enabled with ${AUTO_RATE_MBPS} mbps limit and ${AUTO_BURST_MBPS} burst." && \
        TOR_RATE_MBPS="$AUTO_RATE_MBPS" TOR_BURST_MBPS="$AUTO_BURST_MBPS"
    
fi


msg "\n$_LN\n"


#################################################################
# Ask user if they run other nodes, then set up the fingerprint # 
# family for the Tor node if applicable                         #
#################################################################

if [ -z ${AUTO_USE_FAMILY+x} ]; then
    q_family
else
    if [[ "$AUTO_USE_FAMILY" == "y" ]] && [ -z ${AUTO_FINGERPRINTS+x} ]; then
        >&2 msg bold red "ERROR: AUTO_USE_FAMILY is set to 'y', but AUTO_FINGERPRINTS is not set!"
        >&2 msg bold "To avoid hanging any shell scripts using this, exiting with non-zero status!"
        exit 1
    fi
    msg bold green " [+++] Using AUTO_USE_FAMILY for family enablement: $AUTO_USE_FAMILY"

    TOR_USE_FAMILY="$AUTO_USE_FAMILY"
    [[ "$AUTO_USE_FAMILY" == "y" ]] && TOR_FINGERPRINTS="$AUTO_FINGERPRINTS"
fi


msg bold purple "\n------------- Relay/Exit General Configuration -------------\n"

#############################################################
# Attempt to detect public IPv4 address plus detect public  #
# IPv6 address.                                             #
#                                                           #
# If detection fails, show current server IP configuration, #
# and ask the user to enter the IPv4 / IPv6 address         #
#############################################################

# Set "AUTO_IP_NO_PROMPT" to "y" to disable prompts if detection fails. 
detect_ips

############################################
# Configure whether node is exit or relay  #
# + enable/disable reduced exit policy     #
############################################


if [ -z ${AUTO_IS_EXIT+x} ]; then
    q_is_exit
else
    if [[ "$AUTO_IS_EXIT" == "y" ]] && [ -z ${AUTO_REDUCED_EXIT+x} ]; then
        >&2 msg yellow " [!!!] WARNING: AUTO_IS_EXIT was set to 'y' but AUTO_REDUCED_EXIT was unset."
        >&2 msg yellow " [!!!] Setting AUTO/TOR_REDUCED_EXIT to default of 'y'"
        AUTO_REDUCED_EXIT='y'
    fi
    msg bold green " [+++] Using AUTO_IS_EXIT to decide if relay/exit: AUTO_IS_EXIT = $AUTO_IS_EXIT"
    TOR_IS_EXIT="$AUTO_IS_EXIT"
    [[ "$AUTO_IS_EXIT" == "y" ]] && TOR_REDUCED_EXIT="$AUTO_REDUCED_EXIT"
fi


msg "\n$_LN\n"

#############################
# Reverse DNS configuration #
#############################

if [ -z ${AUTO_RDNS+x} ]; then
    q_rdns
else
    msg bold green " [+++] Using AUTO_RDNS for TOR_RDNS value: AUTO_RDNS = $AUTO_RDNS"
    TOR_RDNS="$AUTO_RDNS"
fi


msg "\n$_LN\n"

##############################
# Node operator contact info #
##############################

if [ -z ${AUTO_NODE_OPERATOR+x} ]; then
    q_operator
else
    msg bold green " [+++] Using AUTO_NODE_OPERATOR for TOR_NODE_OPERATOR value: $AUTO_NODE_OPERATOR"
    TOR_NODE_OPERATOR="$AUTO_NODE_OPERATOR"
fi

msg "\n$_LN\n"

######################################################
# Domain pointed at node (for HTML display purposes) #
######################################################

if [ -z ${AUTO_HAS_DOMAIN+x} ]; then
    q_domain
else
    if [[ "$AUTO_HAS_DOMAIN" == "y" ]] && [ -z ${AUTO_DOMAIN+x} ]; then
        >&2 msg bold red "ERROR: AUTO_HAS_DOMAIN is set to 'y', but AUTO_DOMAIN is not set!"
        >&2 msg bold "To avoid hanging any shell scripts using this, exiting with non-zero status!"
        exit 1
    fi
    msg bold green " [+++] Checking AUTO_HAS_DOMAIN: $AUTO_HAS_DOMAIN"
    TOR_HAS_DOMAIN="$AUTO_HAS_DOMAIN" TOR_DOMAIN="$IPV4_ADDRESS"
    
    [[ "$AUTO_HAS_DOMAIN" == "y" ]] && \
        msg green " [+] (AUTO_DOMAIN) Domain enabled: ${AUTO_DOMAIN}" && \
        TOR_DOMAIN="$AUTO_DOMAIN" || \
        msg yellow " [+] (AUTO_DOMAIN) Domain disabled. Using IP: $IPV4_ADDRESS"
    
fi


msg "\n$_LN\n"

########################################################
# Network speed / capacity (for HTML display purposes) #
########################################################

if [ -z ${AUTO_NETWORK_SPEED+x} ]; then
    q_net_speed
else
    msg bold green " [+++] Using AUTO_NETWORK_SPEED for TOR_NETWORK_SPEED value: $AUTO_NETWORK_SPEED"
    TOR_NETWORK_SPEED="$AUTO_NETWORK_SPEED"
fi


msg "\n$_LN\n"

#############################################################
# Now that we've asked all the important questions, we      #
# show the user a summary of what they've entered so far.   #
#                                                           #
# If the user is happy with their answers, then we can move #
# on to actually writing the configuration.                 #
#############################################################

tor_summary

msg bold cyan "We've summarized your answers above. Please check and make sure everything seems correct."

if { [ -z ${AUTO_SKIP_SUMMARY+x} ] || [[ "$AUTO_SKIP_SUMMARY" != "y" ]]; } && \
       ! yesno "${BOLD}${BLUE}Does everything above look okay? (y/n) >> ${RESET}"; then
    
    # Something is wrong. To save the user some time, we'll ask what specifically is wrong so they can correct it.
    msg yellow "Oh no! Don't worry, we can take you back to the specific question so you can edit your answer."
    _retry_opts() {
        msg bold cyan "Please choose one of the following options:\n"
        msg cyan "\t nick)      Re-configure your chosen node nickname"
        msg cyan "\t ip)        Re-detect your public IPv4 / IPv6 addresses"
        msg cyan "\t limit)     Re-configure your rate limit / burst rate settings"
        msg cyan "\t family)    Re-configure your node family settings"
        msg cyan "\t relay)     Re-configure whether your node is a relay / exit, or enable/disable reduced exit policy"
        msg cyan "\t rdns)      Re-configure your chosen Reverse DNS domain"
        msg cyan "\t operator)  Re-configure your operator name / contact details"
        msg cyan "\t domain)    Re-configure the domain you've selected for the node"
        msg cyan "\t speed)     Re-configure the network speed (to be published on the directory HTML page)"
        msg "-------------------------------------------------------------------------------------------"
        msg green "\t summary)   Show the summary again, including any changes you've made"
        msg green "\t continue)  Accept your current configuration and continue with the setup."
        msg "-------------------------------------------------------------------------------------------"
        msg
    }
    
    _retry_opts

    while true; do
        msg yellow "\n\nIf you need to see the menu options again, type: ${BOLD}help\n"
        ask "Enter your menu choice here >> " RETRY_SEL
        case "$RETRY_SEL" in
            nic*) q_nickname;;
            ip*) detect_ips;;
            lim*) q_rate_limit;;
            fam*) q_family;;
            rel*) q_is_exit;;
            rd*) q_rdns;;
            op*) q_operator;;
            dom*) q_domain;;
            sum*) tor_summary;;
            cont*)
                msg "\n$_LN\n"
                msg green "[+] Exiting re-configuration and continuing setup..."
                msg "\n$_LN\n"
                break
                ;;
            he*|HE*|menu|MENU) _retry_opts;;
            *)
                _retry_opts
                msg red "Invalid choice '$RETRY_SEL' - please choose a valid option from the menu above."
                ;;
        esac
    done
fi

TOR_TMP="$(mktemp -d)"

msg bold purple "\n------------- Generating Config -------------\n"

TMP_TORRC="${TOR_TMP}/torrc"

###############
#
# Generate torrc file
#
###############

msg "\n$_LN\n"

msg bold green " #### Generating torrc file #### "

msg green "Copying template torrc to temporary file ${BOLD}$TMP_TORRC\n"

cp -v "$BASE_TORRC" "$TMP_TORRC"
msg

CURRENT_CONFIG="$TMP_TORRC"

msg green " [+] Removing documentation comments containing 'TPL_' to avoid replacement issues."

sed -E "s/^##[[:space:]].*TPL.*$//" -i "$TMP_TORRC"

msg green " [+] Replacing TPL_REPLACE_NICKNAME with actual nickname: ${BOLD}${TOR_NICKNAME}"
replace "$TMP_TORRC" "TPL_REPLACE_NICKNAME" "$TOR_NICKNAME"

msg green " [+] Replacing TPL_REPLACE_IPV4 with IPv4 address: ${BOLD}${IPV4_ADDRESS}"
# sed -E "s/TPL_REPLACE_IPV4/${IPV4_ADDRESS}/" -i "$TMP_TORRC"
replace "$TMP_TORRC" "TPL_REPLACE_IPV4" "$IPV4_ADDRESS"

if [[ "$HAS_IP6" == "n" ]]; then
    msg yellow " [!!!] No IPv6 support (HAS_IP6 == 'n'). Removing IPv6 lines."
    sed -E 's/^.*TPL_REPLACE_IPV6.*$//' -i "$TMP_TORRC"
else
    msg green " [+] IPv6 is supported (HAS_IP6 == 'y'). Replacing TPL_REPLACE_IPV6 with IPv6 address: ${BOLD}${IPV6_ADDRESS}"
    # sed -E "s/TPL_REPLACE_IPV6/${IPV6_ADDRESS}/" -i "$TMP_TORRC"
    replace "$TMP_TORRC" "TPL_REPLACE_IPV6" "$IPV6_ADDRESS"
fi

msg green " [+] Replacing TPL_REPLACE_CONTACT with operator name / contact info: ${BOLD}${TOR_NODE_OPERATOR}"
# sed -E "s/TPL_REPLACE_CONTACT/${TOR_NODE_OPERATOR}/" -i "$TMP_TORRC"
replace "$TMP_TORRC" "TPL_REPLACE_CONTACT" "$TOR_NODE_OPERATOR"

if [[ "$TOR_USE_LIMIT" == "y" ]]; then
    msg green " [+] Rate limits enabled. Setting RelayBandwidthRate and RelayBandwidthBurst "
    config_set "RelayBandwidthRate" "${TOR_RATE_MBPS} MBits"
    config_set "RelayBandwidthBurst" "${TOR_BURST_MBPS} MBits"
else
    msg green " [+] Rate limits disabled. Commenting out RelayBandwidthRate and RelayBandwidthBurst "
    config_unset "RelayBandwidthRate" "RelayBandwidthBurst"
fi



if [[ "$TOR_USE_FAMILY" == "y" ]]; then
    msg green " [+] User entered fingerprints for other nodes. Setting 'MyFamily'"
    config_set "MyFamily" "$TOR_FINGERPRINTS"
else
    msg green " [+] Node family is disabled. Commenting out 'MyFamily'"
    config_unset "MyFamily"
fi

if [[ "$TOR_IS_EXIT" == "y" ]]; then
    msg green " [+] Node is an exit node. Setting ExitRelay and IPv6Exit."
    config_set "ExitRelay" "1"
    [[ "$HAS_IP6" == "y" ]] && config_set "IPv6Exit" "1" || config_set "IPv6Exit" "0"

    config_unset "ExitPolicy"
    if [[ "$TOR_REDUCED_EXIT" == "y" ]]; then
        msg green " [+] Reduced exit policy is ENABLED. Injecting exit policy into torrc."
        python << EOF
torrc = ""
pol = ""
with open("$EXIT_TORRC") as fp:
    pol = str(fp.read())
with open("$TMP_TORRC") as fp:
    torrc = str(fp.read()).replace('TPL_REPLACE_EXITPOLICY', pol)
with open("$TMP_TORRC", "w") as fp:
    fp.write(torrc)

EOF

    else
        msg green " [+] Reduced exit policy is DISABLED. Setting ExitPolicy to allow all."
        sed -E 's/TPL_REPLACE_EXITPOLICY//' -i "$TMP_TORRC"
        config_set "ExitPolicy" 'accept *:*'
    fi
else
    msg green " [+] Node is a relay node. Disabling ExitRelay and IPv6Exit and ensuring exit policy rejects everything"
    config_unset "ExitPolicy"
    sed -E 's/TPL_REPLACE_EXITPOLICY//' -i "$TMP_TORRC"
    config_set 'ExitRelay' '0'
    config_set 'IPv6Exit' '0'

fi
msg
msg bold green " #### Successfully generated torrc file #### "
msg

###############
#
# Output and install torrc file
#
###############

msg cyan "###### Generated TORRC (minus comments and excess whitespace) ######"
cat "$TMP_TORRC" | sed -E 's/^#.*//' | tr -s '\n'
msg cyan "\n###### End Generated TORRC ######\n"

msg bold green " #### Installing torrc file into $TORRC_FILE #### \n"
install_torrc "$TMP_TORRC" "$TORRC_FILE"
msg bold green "\n #### Success. Copied torrc file to $TORRC_FILE #### \n"

msg "\n$_LN\n"



###############
#
# Generate exit notice HTML file
#
###############

msg bold green " #### Generating exit notice HTML file #### "

TMP_NOTICE="${TOR_TMP}/notice.html"

cp -v "$TORNOTICE_FILE" "$TMP_NOTICE"

# DOMAIN_OR_IP - The domain for this Tor node, or it's IPv4 address
# NODE_OPERATOR - The name of the person/organization operating this Tor exit node.
# NODE_NICKNAME - The nickname of this Tor exit node, e.g. 'privexse1exit'
# NETWORK_SPEED - The network speed or rate limit of this exit, e.g. '100mbps' or 'average 4mbyte/s upload and download'
# DOMAIN_RDNS - The reverse DNS of this Tor exit node, if applicable. Otherwise replace it with N/A
# IPV4_ADDRESS - The public IPv4 address of this Tor exit, e.g. 1.2.3.4
# IPV6_ADDRESS - The public IPv6 address of this Tor exit, e.g. 2a07:e01:abc::1234

if [[ "$TOR_HAS_DOMAIN" == "y" ]]; then
    replace "$TMP_NOTICE" "DOMAIN_OR_IP" "$TOR_DOMAIN"
else
    replace "$TMP_NOTICE" "DOMAIN_OR_IP" "$IPV4_ADDRESS"
fi

replace "$TMP_NOTICE" "NODE_OPERATOR" "$TOR_NODE_OPERATOR"
replace "$TMP_NOTICE" "NODE_NICKNAME" "$TOR_NICKNAME"
replace "$TMP_NOTICE" "NETWORK_SPEED" "$TOR_NETWORK_SPEED"
replace "$TMP_NOTICE" "DOMAIN_RDNS" "$TOR_RDNS"
replace "$TMP_NOTICE" "IPV4_ADDRESS" "$IPV4_ADDRESS"
replace "$TMP_NOTICE" "IPV6_ADDRESS" "$IPV6_ADDRESS"

###############
#
# Install generated exit notice HTML file
#
###############

msg bold green "\n #### Installing exit notice HTML file to $TORNOTICE_OUTPUT #### \n"

safe_copy_file "$TMP_NOTICE" "$TORNOTICE_OUTPUT"

msg bold green "\n #### Success. Copied exit notice file to $TORNOTICE_OUTPUT #### \n"

msg "\n$_LN\n"

###############
#
# Install nginx configuration
#
###############

msg bold green "\n #### Installing nginx configuration to $OUT_NGINX #### \n"
safe_copy_file "$BASE_NGINX" "$OUT_NGINX"
msg bold green "\n #### Success. Installed nginx config at $OUT_NGINX #### \n"

msg "\n$_LN\n"


if [ -z ${AUTO_RESTART_SERVICES+x} ] || [ "$AUTO_RESTART_SERVICES" == "y" ]; then
    msg bold green " [+] Enabling / restarting nginx and Tor"
    if has_command systemctl; then
        msg bold green " [+] Detected 'systemctl'. Enabling nginx and tor@default ensuring they start on reboot."
        sudo systemctl enable nginx
        sudo systemctl enable tor@default
        msg bold green " [+] (Re)starting nginx and tor@default"
        sudo systemctl restart nginx
        sudo systemctl restart tor@default
    elif has_command service; then
        msg bold green " [+] Detected 'service'. Restarting nginx and tor."
        service tor restart
        service nginx restart
    else
        msg bold red " [!!!] Could not find the commands 'systemctl' nor 'service'. " \
                     "       You'll need to restart nginx and tor yourself."
    fi
else
    msg green " [+++] Skipping restarting services as AUTO_RESTART_SERVICES is set (and is not 'y')"
fi

msg "\n$_LN\n"

msg
msg
msg bold cyan "#################################################################"
msg bold cyan "#                                                               #"
msg bold cyan "# TorSetup has completed successfully.                          #"
msg bold cyan "# Your Tor relay/exit should now be running at:                 #"
msg bold cyan "#                                                               #"
msg bold cyan "#      ${IPV4_ADDRESS}:443                             \t\t#"
if [[ "$HAS_IP6" ]]; then
    msg bold cyan "#                                                               #"
    msg bold cyan "#      [${IPV6_ADDRESS}]:443                   \t\t#"
fi
msg bold cyan "#                                                               #"
msg bold cyan "#################################################################"
msg bold cyan "#                                                               #"
msg bold cyan "# Your Tor relay/exit notice should be displayed at:            #"
msg bold cyan "#                                                               #"
msg bold cyan "#      http://${TOR_DOMAIN}                 \t\t#"
msg bold cyan "#      http://${IPV4_ADDRESS}                         \t\t#"
msg bold cyan "#                                                               #"
msg bold green "#################################################################"
msg bold green "#                                                               #"
msg bold green "#  THANK YOU FOR USING TorSetup!                                #"
msg bold green "#  TorSetup was developed by Privex Inc.                        #"
msg bold green "#                (https://www.privex.io)                        #"
msg bold green "#                                                               #"
msg bold green "#  TorStatus is open source under the GNU AGPL v3               #"
msg bold green "#  Github: https://github.com/Privex/tor-setup                  #"
msg bold green "#                                                               #"
msg bold green "#################################################################"
msg






