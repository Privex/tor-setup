#!/usr/bin/env bash


if [ -z ${TORSETUP_DIR+x} ]; then
    _DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    grep -q "/lib" <<< "$_DIR" && TORSETUP_DIR=$(dirname "$_DIR") || TORSETUP_DIR="$_DIR"
fi

# if [ -z ${TORSETUP_FUNCS_LOADED+x} ]; then
#     source "${TORSETUP_DIR}/lib/functions.sh" || { 
#         >&2 echo "${BOLD}${RED}[questions.sh] CRITICAL ERROR: Could not load functions file at '${TORSETUP_DIR}/lib/functions.sh' - Exiting!${RESET}"
#         exit 1
#     }
# fi

[ ! -z ${TORSETUP_FUNCS_LOADED+x} ] || source "${TORSETUP_DIR}/lib/functions.sh" || { 
    >&2 echo "${BOLD}${RED}[questions.sh] CRITICAL ERROR: Could not load functions file at '${TORSETUP_DIR}/lib/functions.sh' - Exiting!${RESET}"
    exit 1
}

TORSETUP_QUESTIONS_LOADED='y'     # Used to detect if this file has already been sourced or not


# Ask user for the node nickname they want
# Output variable(s):   TOR_NICKNAME
q_nickname() {
    ask "What nickname should we use for your node, for example 'JohnDoeExitSE' ${RESET}>>> " \
        TOR_NICKNAME "ERROR: Please enter a nickname." n yes
}

# Ask user for the rate limit + burst limit they want, in mbps
# NOTE: you probably want to call q_rate_limit instead, which asks whether the user wants rate limiting or not
# Output variable(s):   TOR_RATE_MBPS (integer)    TOR_BURST_MBPS (integer)
set_rate_limit() {
    local ratenum burstnum
    while true; do
        msg
        ask "Please enter how many megabits per second (mbps) your Tor node should aim to stay under (RelayBandwidthRate) ${RESET}>>> " \
            TOR_RATE_MBPS "ERROR: Please enter a valid number for the RelayBandwidthRate question." number
        msg
        msg yellow "NOTE: For the following question - RelayBandwidthBurst should be EQUAL TO, or GREATER than RelayBandwidthRate - do not enter 0 or a lower rate."
        ask "Please enter how many megabits per second (mbps) your Tor node should use at most (RelayBandwidthBurst) ${RESET}>>> " \
            TOR_BURST_MBPS "ERROR: Please enter a valid number for the RelayBandwidthRate question." number

        msg "\n$_LN\n"
        msg green "You entered for the rate limit (RelayBandwidthRate): $TOR_RATE_MBPS megabits per second (mbps)"
        msg green "You entered for the burst rate (RelayBandwidthBurst): $TOR_BURST_MBPS megabits per second (mbps)"
        msg "\n$_LN\n"

        if yesno "Are the above numbers correct? (Y/n) > " defyes; then
            msg green "Great! Let's continue with the setup."
            break
        else
            msg yellow "Oh no :( - We'll ask you the questions again so you can fix them."
        fi
    done
}

# Ask user if they want to set up rate limiting for their node, then prompt for rate limit + burst limit
# Output variable(s):  TOR_USE_LIMIT (y/n)   TOR_RATE_MBPS (integer)    TOR_BURST_MBPS (integer)
q_rate_limit() {

    msg bold purple "------------- Network rate limiting ------------- "
    msg
    msg green "If your Privex server has a ${BOLD}limited amount of bandwidth per month${RESET}${GREEN}, then you should configure a network speed limit."
    msg
    msg green "If your Privex server has ${BOLD}'unmetered'${RESET}${GREEN} networking, e.g. our Tor node packages, then you do not need to configure a network speed limit, unless you"
    msg green "plan to run other applications on this server, and would like to ensure some of your network capacity is kept available for other applications."
    msg
    msg bold cyan "Examples of speed limits and how much bandwidth may be used:\n"
    msg green "\t A speed limit of ${BOLD}10 megabits per second (10mbps)${RESET}${GREEN} would generally result in bandwidth usage of up to" \
            "108 gigabytes per day, or 3.3 terabytes per month.\n"
    msg green "\t A speed limit of ${BOLD}50 megabits per second (50mbps)${RESET}${GREEN} would generally result in bandwidth usage of up" \
            "to 540 gigabytes per day, or 17 terabytes per month.\n"


    if yesno "${BOLD}${BLUE}Do you want to set a network speed rate limit on your Tor node? (y/n) ${RESET}>>> "; then
        TOR_USE_LIMIT="y"

        msg bold purple "\n------------- Understanding megabits ------------- \n"
        msg
        msg bold "The following questions expect a plain number representing mega*BITS* per second."
        msg "Megabits are usually expressed as 'mbps' (megabits per second), while megabytes are usually mb/s or mbyte/s"
        msg "Eight (8) megabits is equal to One (1) megabyte. 100 mbit/s == 12.5 mbyte/s, 1 gigabit (gbps) == 1000mbps == 125 mbyte/s"
        msg
        msg green "Two types of speed limits can be configured, ${BLUE}${BOLD}RelayBandwidthRate${RESET}${GREEN} (rate limit) and" \
                "${BLUE}${BOLD}RelayBandwidthBurst${RESET}${GREEN} (temporary bursts)\n"
        msg "\t - ${BLUE}${BOLD}RelayBandwidthRate${RESET}, the average network speed that your Tor node should aim to stay under\n"
        msg "\t - ${BLUE}${BOLD}RelayBandwidthBurst${RESET}, the 'burst' rate, if set higher than the normal rate, then occasionally the network speed may increase"
        msg "\t   up to this speed for a short period of time (e.g. only for a few minutes every hour)"
        
        set_rate_limit

    fi
}

# Ask user if they run any other tor relays/exits, then prompt for their fingerprints if known
# Output variable(s):  TOR_USE_FAMILY (y/n)   TOR_FINGERPRINTS (ABCD123 DEFA456 DBCA890)
q_family() {
    msg bold purple "\n------------- Tor Node Family -------------\n"

    msg bold yellow "NOTE:${RESET}${YELLOW} If the only other node you're operating is a ${BOLD}${CYAN}BRIDGE node${RESET}${YELLOW}, enter no for the next question."
    msg yellow "Tor bridges are supposed to be kept hidden, so they should not be entered in your Tor node's family config.\n"

    if yesno "${BOLD}${BLUE}Do you operate any other Tor relays or exit nodes? (y/n) ${RESET}>>> "; then
        msg
        msg purple "It's strongly recommended to configure your 'Tor node family', which is a list of fingerprints of other Tor nodes which you operate."
        msg purple "This is used to ensure Tor clients will never build a path with more than one of your nodes in the Tor path."
        msg purple "Please find the fingerprints of your other Tor relays / exit nodes. You can generally find the fingerprint by running:\n"
        msg "\tsudo cat /var/lib/tor/fingerprint\n"
        msg purple "on each Tor node. You only need the hexadecimal fingerprints which look like: ${BOLD}ABCD1234ABCD1234"
        msg
        msg green "Alternatively, you can search for your relays/exits and find their fingerprints using the Tor project's Relay Search tool:"
        msg "\n\t https://metrics.torproject.org/rs.html \n"
        if yesno "${BOLD}${BLUE}Do you wish to configure a Tor node family? (Y/n) ${RESET}>>> " defyes; then
            TOR_USE_FAMILY="y"
            msg
            ask "Please enter each fingerprint of your other Tor nodes, separated by a space ${RESET}>>> " \
                TOR_FINGERPRINTS "ERROR: Please enter one or more fingerprints, separated by spaces." n yes
        fi
    fi
}
# Detect if user has IPv4, otherwise ask them to find their IPv4 address
# NOTE: you probably want to call detect_ips instead, which calls both detect_ipv4 and detect_ipv6
# Output variable(s): HAS_IP4 (y/n)   IPV4_ADDRESS (1.2.3.4)
detect_ipv4() {
    msg yellow " [-] Checking if your server has IPv4 support...\n"
    if myip4 > /dev/null; then
        IPV4_ADDRESS=$(myip4)
        msg green " [+] SUCCESS. IPv4 address detected: ${IPV4_ADDRESS}\n"
        HAS_IP4='y'
        return 0
    fi
    if [ ! -z ${AUTO_IP_NO_PROMPT+x} ] && [[ "$AUTO_IP_NO_PROMPT" == "y" ]]; then
        >&2 msg red " [!!!] Failed to detect public IPv4 address. Skipping prompt as AUTO_IP_NO_PROMPT is enabled"
        >&2 msg red " [!!!] As setting up a Tor node requires IPv4, returning non-zero code to abort setup..."
        return 1
    fi
    ip -4 addr
    msg bold red "ERROR: We could not automatically determine your primary IPv4 address\n"
    msg yellow "Please look at your server's IPv4 configuration above, and tell us what your PUBLIC IPv4 address is (excluding the /xx subnet portion)."
    msg yellow "Privex servers normally have an IP address that looks like: 185.130.44.xx "
    msg yellow "IP addresses which look like '10.x.x.x', '192.168.x.x' or '172.16.x.x' are NOT public IPv4 addresses."
    msg
    ask "Please enter your server's public IPv4 address (excluding the /xx subnet portion) ${RESET}>>> " \
            IPV4_ADDRESS "ERROR: Please enter your server's public IPv4 address!" n yes
    HAS_IP4='y'
}

# Detect if user has IPv6, otherwise ask them to find their IPv6 address
# NOTE: you probably want to call detect_ips instead, which calls both detect_ipv4 and detect_ipv6
# Output variable(s): HAS_IP6 (y/n)   IPV6_ADDRESS (2a07:e01:abc:def::2)
detect_ipv6() {
    msg yellow " [-] Checking if your server has IPv6 support...\n"
    if myip6 > /dev/null; then
        IPV6_ADDRESS=$(myip6)
        msg green " [+] SUCCESS. IPv6 address detected: ${IPV6_ADDRESS}\n"
        HAS_IP6='y'
        return 0
    fi

    HAS_IP6='n'
    if [ ! -z ${AUTO_IP_NO_PROMPT+x} ] && [[ "$AUTO_IP_NO_PROMPT" == "y" ]]; then
        msg red " [!!!] Failed to detect public IPv6 address. Skipping prompt as AUTO_IP_NO_PROMPT is enabled. "
        return 0
    fi
    
    ip -6 addr
    msg bold red "ERROR: We could not automatically determine your primary IPv6 address\n"
    msg yellow "Please look at your server's IPv6 configuration above, and tell us what your PUBLIC IPv6 address is (excluding the /xx subnet portion)."
    msg yellow "Privex servers normally have an IPv4 address that looks like: 2a07:e01:ab:c1::2 "
    msg yellow "IPv6 addresses which begin with 'fe80:' are NOT public IPv6 addresses."
    msg
    msg bold yellow "If your server DOES NOT have a public IPv6 address, please just leave the answer blank and press ENTER to disable IPv6 on your Tor node."
    ask "Please enter your server's public IPv6 address (excluding the /xx subnet portion) ${RESET}>>> " IPV6_ADDRESS "" allowblank yes
    msg
    if [ -z "$IPV6_ADDRESS" ]; then
        msg red " [!!!] Your response was empty. We'll assume you don't have IPv6 support and disable IPv6 on your Tor node.\n"
    else
        msg green " >> Your response was non-empty: $IPV6_ADDRESS\n"
        msg green " [+] Enabling IPv6 support for your Tor node :)\n"
        HAS_IP6='y'
    fi
}

# Detect public IPv4 / IPv6 of this node
# Output variable(s): HAS_IP4 (y/n)   HAS_IP6 (y/n)   IPV4_ADDRESS (1.2.3.4)   IPV6_ADDRESS (2a07:e01:abc:def::2)
detect_ips() {

    msg bold green " >>> Automatically detecting your server's public IPv4 and IPv6 addresses...\n"
    detect_ipv4
    detect_ipv6
    msg bold green " +++ Finished IP address configuration \n"
}

# Ask user if they want to use our reduced exit node policy
# NOTE: you probably want to use q_is_exit instead, which calls this function.
# Output variable(s): TOR_REDUCED_EXIT (y/n)
q_reduced_exit() {
    msg purple "To help reduce the amount of abuse emails that a Tor exit node produces, as well as helping prevent malicious uses of the Tor network"
    msg purple "such as email spam, SSH and SQL database brute forcing, and malicious persons using exploits, ${BOLD}we've included a Reduced Exit Policy."
    msg
    msg purple "The ${BOLD}'Reduced Exit Policy'${RESET}${MAGENTA} we include, is based on the official reduced exit policy from the" \
               "Tor wiki https://trac.torproject.org/projects/tor/wiki/doc/ReducedExitPolicy"
    msg purple "and has been ${BOLD}slightly modified and updated by Privex${RESET}${MAGENTA} to both reduce the amount of abuse reports caused by Tor exit nodes"
    msg purple "without impacting the majority of Tor users - plus some new service port whitelist additions".
    msg
    msg purple "If you're not using this setup tool on a Privex server, or you've been otherwise authorized to run your exit without a reduced exit policy, then"
    msg purple "you'll be given the option to use a standard 'allow everything' exit policy after the following question:"
    msg
    if yesno "${BOLD}${BLUE}Would you like to view the included Reduced Exit Policy? (Y/n) ${RESET}>>> " defyes; then
        msg bold green "# -------    Reduced exit policy at ${EXIT_TORRC}     -------"
        cat "$EXIT_TORRC"
        msg bold green "# ------- End of reduced exit policy at ${EXIT_TORRC} -------"
    fi
    msg
    msg
    if yesno "${BOLD}${BLUE}Do you want to use the included Reduced Exit Policy (strongly recommended)? (Y/n) ${RESET}>>> " defyes; then
        msg green "\n [+] Setting 'Use reduced exit policy' to ${BOLD}YES\n"
        TOR_REDUCED_EXIT="y"
    else
        msg yellow "\n [+] Setting 'Use reduced exit policy' to ${BOLD}${RED}NO\n"
        msg purple "Your exit policy will be set to allow everything: ${BOLD}ExitPolicy accept *:*\n"
    fi
}

# Ask user if they want to run an exit node, and offer reduced exit node policy
# Output variable(s): TOR_IS_EXIT (y/n)  TOR_REDUCED_EXIT (y/n)
q_is_exit() {
    msg purple "If you say no to the following question, then your Tor node will be configured as a non-exit relay."

    if yesno "${BOLD}${BLUE}Do you want this Tor node to be an EXIT node? (y/n) ${RESET}>>> "; then
        TOR_IS_EXIT="y"
        msg green "\n [+] Configuring your node as a Tor ${BOLD}Exit Node\n"

        #######################
        # REDUCED EXIT POLICY #
        #######################
        q_reduced_exit
    else
        msg green "\n [+] Configuring your node as a Tor ${BOLD}Relay Node (Not an Exit)\n"
    fi
}

# Print reverse DNS for $IPV4_ADDRESS and $IPV4_ADDRESS (if HAS_IP6 is 'y')
show_rdns() {
    msg
    msg green "\t IPv4 address:\t ${BOLD}${IPV4_ADDRESS}"
    msg green "\t IPv4 Reverse DNS:\t ${BOLD}$(dig +short -x $IPV4_ADDRESS)"
    msg
    if [[ "$HAS_IP6" == 'y' ]]; then
        msg green "\t IPv6 address:\t ${BOLD}${IPV6_ADDRESS}"
        msg green "\t IPv6 Reverse DNS:\t ${BOLD}$(dig +short -x $IPV6_ADDRESS)"
    else
        msg yellow "\t IPv6 address not found / configured on this server. Skipping rDNS."
    fi
    msg
}

# Show user current IPv4 / v6 reverse DNS, then ask user for planned reverse DNS (for HTML display)
# Output variable(s): TOR_RDNS e.g. www.example.com  OR 'n/a'
q_rdns() {
    msg bold purple "Reverse DNS configuration"
    msg purple "For the Tor server notice we'll display on port 80 (HTTP), we display your server's Reverse DNS (rDNS)"
    msg purple "Below is the current reverse DNS published for your IPv4 and IPv6 (if enabled) addresses"

    show_rdns

    msg purple "If you don't yet have a reverse DNS which makes it clear that this is a Tor node, we strongly recommend setting"
    msg purple "up reverse DNS which matches a domain you own, such as ${BOLD}tor-exit-node1.mydomain.com"
    msg purple "You can do this either via your provider's server panel, or by emailing their customer support."
    msg
    msg purple "If you plan to set up reverse DNS later, you can just enter the domain you plan to have set on your IPv4/v6 rDNS"
    msg purple "If this is only a relay, then reverse DNS isn't too important - you can skip it just by typing 'n/a'"
    msg
    ask "Please enter the (planned) rDNS domain you'd like displayed on the Tor notice page, e.g. tor-exit.mydomain.com ${RESET}>>> " \
                TOR_RDNS "ERROR: Please enter a domain." n yes
}


# Ask user for node operator name / contact details
# Output variable(s): TOR_NODE_OPERATOR e.g. John Doe (www.example.com)
q_operator() {
    msg bold purple "Node operator contact information"
    msg
    msg purple "This will be displayed on your Tor node's metadata when people look at lists of tor relays/exits"
    msg purple "This will also be shown on the ${BOLD}Tor HTML notice${RESET}${MAGENTA} that will be available on this server's port 80."
    msg purple "Common formatting examples:"
    msg
    msg purple "\ta simple name or username, e.g. ${BOLD}John Doe"
    msg purple "\ta name + website e.g. ${BOLD}ExampleCo Ltd. (https://example.org)"
    msg purple "\ta name + email e.g. ${BOLD}Dave (dave [at] example (.) org)"
    msg
    msg purple "It's important (but not mandatory) that you include *some* way of contacting you / others with access to the node, as the contact information"
    msg purple "can sometimes be used to alert a node operator of an urgent security issue with their node, or misconfigurations that are causing problems."
    msg bold purple "NOTE: (For exit operators!) The contact information that you publish for your Tor node generally DOES NOT get used for spammy abuse reports.\n" \
                    "      Generally, abuse reports are sent to the abuse email listed on WHOIS databases for the IP address which caused the abuse."
    msg

    ask "Please enter the operator name and/or contact details to be published for your Tor node ${RESET}>>> " \
        TOR_NODE_OPERATOR "ERROR: Please enter your operator name / contact info." n yes
}


# Ask user for expected domain pointed to their node
# Output variable(s): TOR_HAS_DOMAIN (y/n) TOR_DOMAIN (format: example.com    or 1.2.3.4 if no domain)
q_domain() {
    if yesno "${BOLD}${BLUE}Do you have a domain/subdomain pointing at this tor node (or plan to point one soon)? (y/N) >> ${RESET}" defno; 
    then
        TOR_HAS_DOMAIN='y'
        ask "Please enter the domain (e.g. tor-node.example.com ) you're pointing (or plan to) at this Tor server ${RESET}>>> " \
            TOR_DOMAIN "ERROR: Please enter your operator name / contact info." n yes
        msg green "\n [+] Setting your Tor node's public domain to ${BOLD}${TOR_DOMAIN}\n"
    else
        TOR_HAS_DOMAIN='n' TOR_DOMAIN="$IPV4_ADDRESS"
        msg red "\n [!!!] No public domain... We'll just display your IPv4 address '$IPV4_ADDRESS' instead.\n"
    fi
}

# Ask user for expected network speed of their node (for directory HTML display)
# Output variable(s): TOR_NETWORK_SPEED (format: 100mbps)
q_net_speed() {
    msg
    msg purple " (?) For the below question. On the Tor HTML notice (aka tor directory port notice), we display a network speed, which allows people to find out"
    msg purple "     how much capacity this Tor node can handle / is handling."
    msg
    msg purple "     If you set a rate limit earlier, for example 40mbps rate limit with 80mbps burst, then you should answer the next question with: 40-80 mbps"
    msg purple "     If you didn't set a rate limit, then enter your servers network speed in mbps, for example: 100mbps"
    msg
    msg purple "     If you ${BOLD}don't know your server's network speed${RESET}${MAGENTA}, just enter: 20mbps      (it can be changed later)"
    msg

    ask "What network speed should be displayed on the Tor HTML notice? ${RESET}>>> " \
                TOR_NETWORK_SPEED "ERROR: Please enter your network speed, e.g. 100mbps" n yes
    
}

tor_summary() {
    msg bold green "##########################################################"
    msg bold green "#                                                        #"
    msg bold green "#                                                        #"
    msg bold green "#               Configuration Summary                    #"
    msg bold green "#                                                        #"
    msg bold green "#                                                        #"
    msg bold green "##########################################################"

    msg
    [[ "$TOR_REDUCED_EXIT" == "y" ]] && _REX='YES' || _REX='NO'
    [[ "$TOR_USE_LIMIT" == "y" ]] && _RL='YES' || _RL='NO'
    [[ "$TOR_USE_FAMILY" == "y" ]] && _HVFAM='YES' || _HVFAM='NO'

    _EX_MSG="Node type\t${BOLD}EXIT NODE" 
    _RP_MSG="Reduced exit policy\t${BOLD}${_REX}"

    {
        [[ "$HAS_IP4" == "y" ]] && msg green "IPv4 Address\t${BOLD}${IPV4_ADDRESS}\n"
        [[ "$HAS_IP6" == "y" ]] && msg green "IPv6 Address\t${BOLD}${IPV6_ADDRESS}\n"

        msg green "Node nickname\t${BOLD}${TOR_NICKNAME}"
        [[ "$TOR_IS_EXIT" == "y" ]] && msg green "$_EX_MSG" && msg green "$_RP_MSG" || msg green "Node type\t${BOLD}Relay node (not an exit)"

        msg green "Have other Tor nodes?\t${BOLD}$_HVFAM"
        [[ "$TOR_USE_FAMILY" == "y" ]] && msg green "Family fingerprints\t${BOLD}$TOR_FINGERPRINTS"

        msg green "Rate limiting\t${BOLD}$_RL"
        [[ "$TOR_USE_LIMIT" == "y" ]] && msg green "Limit // Burst\t${BOLD}$TOR_RATE_MBPS mbps // $TOR_BURST_MBPS mbps"

        msg green "Reverse DNS\t${BOLD}$TOR_RDNS"
        msg green "Operator Name/Contact\t${BOLD}${TOR_NODE_OPERATOR}"
        msg green "Domain for the node\t${BOLD}${TOR_DOMAIN}"
        msg green "Network speed\t${BOLD}${TOR_NETWORK_SPEED}";
    } | column -t -s $'\t'

    msg "\n$_LN\n"
}