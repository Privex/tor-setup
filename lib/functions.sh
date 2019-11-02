#!/usr/bin/env bash

: ${CURRENT_CONFIG='/etc/tor/torrc'}   # If CURRENT_CONFIG isn't specified by the sourcing script, then it defaults to this.

_sc_fail() { >&2 echo "[functions.sh] Failed to load or install Privex ShellCore..." && exit 1; }  # Error handling function for ShellCore

# If S_CORE_VER is undefined, then we need to load ShellCore from this file. Otherwise no need to do anything.
if [ -z ${S_CORE_VER+x} ]; then
    # If `load.sh` isn't found in the user install / global install, then download and run the auto-installer from Privex's CDN.
    [[ -f "${HOME}/.pv-shcore/load.sh" ]] || [[ -f "/usr/local/share/pv-shcore/load.sh" ]] || \
        { curl -fsS https://cdn.privex.io/github/shell-core/install.sh | bash >/dev/null; } || _sc_fail
    # Attempt to load the local install of ShellCore first, then fallback to global install if it's not found.
    [[ -d "${HOME}/.pv-shcore" ]] && source "${HOME}/.pv-shcore/load.sh" || source "/usr/local/share/pv-shcore/load.sh" || _sc_fail
fi

if [ -z ${TORSETUP_DIR+x} ]; then
    _DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    grep -q "/lib" <<< "$_DIR" && TORSETUP_DIR=$(dirname "$_DIR") || TORSETUP_DIR="$_DIR"
fi

# DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

TORSETUP_FUNCS_LOADED='y'     # Used to detect if this file has already been sourced or not
: ${TOR_DEBUG=0}              # Set to 1 to enable debugging messages

_tordebug() {
    (($TOR_DEBUG!=1)) && return
    msgerr ts "$@"
}

# Small alias function to check if sudo needs a password or not.
# e.g.
#     if sudo_works; then
#          sudo apt install -y curl
#     else
#          msg red "Passwordless sudo isn't available, so cannot install curl!"
#     fi
sudo_works() {
    [ "$EUID" -ne 0 ] && sudo -n ls / || true
}


# bash in-line python snippet to sanely replace things in files when
# sed doesn't like special chars...
# usage: replace example.txt "hello world" "my replacement"
# above example would replace the text 'hello world' with 'my replacement' in the file example.txt
replace() {
    local srcfile="$1" findtxt="$2" replacetxt="$3"
    python << EOF
with open("$srcfile") as fp:
    data = str(fp.read()).replace("$findtxt", "$replacetxt")
with open("$srcfile", "w") as fp:
    fp.write(data)

EOF

}


#
# Tor Node Config
#
get_config_location() {
    if [[ ! -z "$CURRENT_CONFIG" ]]; then
        echo "$CURRENT_CONFIG"
    else
        echo "$PWD/torrc"
    fi
}

has_item() {
    grep -c "^$1" $(get_config_location)
}

config_set() {
    _tordebug "Setting $1 to $2 in file $(get_config_location)"
    if [[ $(has_item $1) -eq 0 ]]; then
        # config item not found. try to uncomment
        sed -i -e 's/^#[[:space:]]'"$1"'.*/'"$1 $2"'/' $(get_config_location)
        if [[ $(has_item $1) -eq 0 ]]; then
            >&2 echo "WARNING: $1 was not found as a comment. Prepending to the start of the file"
            # is it still not here? fine. we'll add it to the start
            prepend_config "$1 $2"
        fi
    else
        # already an entry, let's replace it
        sed -i -e "s/^$1.*/$1 $2/" $(get_config_location)
    fi
}

config_unset() {
    for conitem in "$@"
    do
        _tordebug "Removing item $conitem from $(get_config_location)"

        if [[ $(has_item $conitem) -eq 1 ]]; then
            sed -i -e 's/^'"$conitem"'.*/# \0/' $(get_config_location)
        fi
    done
}

prepend_config() {
    prep=$(echo $1 && cat $(get_config_location)) 
    echo $prep > $(get_config_location)
}

myip4 () {
    curl -4 -fsSL http://icanhazip.com
}

myip6 () {
    curl -6 -fsSL http://icanhazip.com
}

# Usage:
# ask [question] [outputvar] [errormsg] [typecheck] [confirmval]
#
# typecheck - default: do not allow blank answers.   
#              number: check that the answer contains a valid non-zero number
#          allowblank: do not validate the answer - allow empty responses.
#
# NOTE: By default, question is colorized bold blue, and errormsg bold red.
#       If you specify "" for errormsg then the default will be used
#       If you specify "" or a non-existent option for typecheck, then the default will be used.
#
#   $ ask "Please enter your name > " MY_VAR
#     Please enter your name > 
#     ERROR: You must enter an answer
#     Please enter your name > john
#   $ echo "$MY_VAR"
#     john
#
#   $ ask "Please enter a number > " MY_NUM "You must enter a valid number other than zero!" number yes
#     Please enter a number > orange
#     You must enter a valid number other than zero!
#     Please enter a number > 123
#     You entered: 123
#     Does this look correct? (Y/n) > 
#   $ echo "$MY_NUM"
#     123
#
ask() {
    local question answer output errormsg="ERROR: You must enter an answer!" typecheck="" confirmval="no" numanswer
    if (($#<2)); then
        msg red "ERROR: You must specify at least the question and the output variable."
        return 1
    fi
    question="$1" output="$2"
    (($#>=3)) && { [ -z "$3" ] && errormsg="$errormsg" || errormsg="$3"; };
    (($#>=4)) && typecheck="$4"
    (($#>=5)) && confirmval="$5"

    while true; do
        msg
        read -p "${BOLD}${BLUE}${question}${RESET}" "$output"
        answer=$(eval "echo \$$output")

        if [ "$typecheck" != "allowblank" ] && [ -z "$answer" ]; then
            msg red "\n$errormsg\n"
            continue
        fi

        if [[ "$typecheck" == "number" ]]; then
            numanswer=$(($answer))
            if ((numanswer==0)); then
                msg red "\n$errormsg\n"
                continue
            fi
            eval "${output}=\$(($answer))"
            answer=$(eval "echo \$$output")
        fi

        if [[ "$confirmval" == "y" ]] || [[ $confirmval == "yes" ]]; then
            [ -z "$answer" ] && msg yellow "\nYou've left the answer blank. $answer\n" || msg green "\nYou've entered the answer: $answer\n"
            
            if yesno "Does that look correct? (Y/n) > " defyes; then
                msg green "Great! Let's continue."
            else
                msg yellow "Oh no :( - We'll ask you again."
                continue
            fi
        fi
        break
    done
}

install_tor_deps() {
    if [ -z ${AUTO_PKG_INSTALL+x} ] || [[ "$AUTO_PKG_INSTALL" != "y" ]]; then
        msg bold green " >>> Checking all required packages are installed..."
        if [[ "$(uname -s)" == "Linux" ]]; then
            msg bold cyan "NOTE: If you aren't running this as root, you may get sudo password prompts for package installation."
            msg bold cyan "      Disable automatic package installation by running: AUTO_PKG_INSTALL='n' $0"

            echo -ne "${YELLOW} ... dig (dnsutils)"
            pkg_not_found dig dnsutils
            echo -ne "${GREEN} [ +++ installed/found +++ ] ${RESET}\n"

            echo -ne "${YELLOW} ... nginx"
            pkg_not_found nginx nginx
            echo -ne "${GREEN} [ +++ installed/found +++ ] ${RESET}\n"

            echo -ne "${YELLOW} ... tor"
            pkg_not_found tor tor
            echo -ne "${GREEN} [ +++ installed/found +++ ] ${RESET}\n"
        else
            echo -ne "${YELLOW} ... dig (dnsutils)"
            has_binary dig && echo -ne "${GREEN} [ +++ found +++ ] ${RESET}\n" || echo -ne "${RED} [ !!! NOT FOUND !!! ] ${RESET}\n"

            echo -ne "${YELLOW} ... nginx"
            has_binary nginx && echo -ne "${GREEN} [ +++ found +++ ] ${RESET}\n" || echo -ne "${RED} [ !!! NOT FOUND !!! ] ${RESET}\n"
            
            echo -ne "${YELLOW} ... tor"
            has_binary tor && echo -ne "${GREEN} [ +++ found +++ ] ${RESET}\n" || echo -ne "${RED} [ !!! NOT FOUND !!! ] ${RESET}\n"

            msg
            msg yellow "WARNING: Unsupported operating system '$(uname -s)' - cannot auto-install packages"
            msg yellow "Please make sure the following packages are installed: ${BOLD} dnsutils (for dig), nginx, tor"
            sleep 2
            unset -f pkg_not_found
            pkg_not_found() {
                >&2 msg "[pkg_not_found] WARNING: Unsupported operating system '$(uname -s)' - cannot auto-install packages"
            }
        fi
    else
        msg cyan " [...] Skipping automatic package detection/installation as AUTO_PKG_INSTALL is set to 'y'"
    fi
}

safe_mkdir() {
    local dest_dir="$1" dest_dir_parent
    dest_dir_parent=$(dirname "$dest_dir")

    if [[ ! -d "$dest_dir" ]]; then
        msg yellow " [!] Warning: Destination folder '$dest_dir' doesn't exist. Will try and create it."
        # if ! can_write "$dest_dir_parent"; then
        #     msg yellow " [!] Warning: Cannot write to containing folder '$dest_dir_parent'. Trying sudo."
        #     sudo mkdir -p "$dest_dir"
        # else
        #     msg green " [+] Looks like we have write permission. Attempting to create folder '$dest_dir'"
            if ! mkdir -p "$dest_dir"; then
                msg yellow " [!] Warning: Error creating '$dest_dir'. Trying sudo."
                sudo mkdir -p "$dest_dir"
            fi
        # fi
        msg green " [+] Successfully created folder '$dest_dir''"
    fi
}

safe_copy_file() {
    local from_file="$1" to_file="$2" dest_dir dest_dir_parent 

    dest_dir=$(dirname "$to_file")
    # dest_dir_parent=$(dirname "$dest_dir")

    # if [[ ! -d "$dest_dir" ]];
    #     msg yellow " [!] Warning: Destination folder '$dest_dir' doesn't exist. Will try and create it."
    #     if ! can_write "$dest_dir_parent"; then
    #         msg yellow " [!] Warning: Cannot write to containing folder '$dest_dir_parent'. Trying sudo."
    #         sudo mkdir -p "$dest_dir"
    #     else
    #         msg green " [+] Looks like we have write permission. Attempting to create folder '$dest_dir'"
    #         if ! mkdir -p "$dest_dir"; then
    #             msg yellow " [!] Warning: Error creating '$dest_dir'. Trying sudo."
    #             sudo mkdir -p "$dest_dir"
    #         fi
    #     fi
    # fi

    safe_mkdir "$dest_dir"
    msg
    if can_write "$dest_dir"; then
        msg green " [+] Looks like we have write permission to '$dest_dir'. Attempting to copy file."
        if ! cp "$from_file" "$to_file"; then
            msg yellow " [!] Warning: Error copying into '$to_file'. Trying sudo."
            sudo cp -v "$from_file" "$to_file"
        fi
    else
        msg yellow " [!] Warning: Cannot write to dest folder '$dest_dir'. Trying sudo."
        sudo cp -v "$from_file" "$to_file"
    fi
    msg green " [+] Successfully copied file '$from_file' to '$to_file'"
    msg
}

# install_torrc [src] [dest]
install_torrc() {
    local from_file="$1" to_file="$2" dest_dir dest_dir_parent tmp_src=$(mktemp)
    dest_dir=$(dirname "$to_file")
    dest_dir_parent=$(dirname "$dest_dir")

    msg green " [+] Installing generated Torrc file\n" 
    msg green "\tSource:\t$from_file"
    msg green "\tDest:\t$to_file"
    msg

    {
        cat "$HEADER_TORRC"
        cat "$from_file" | sed -E 's/^#.*//' | tr -s '\n'
        cat "$FOOTER_TORRC"
    } > "$tmp_src"

    msg green " [+] Rendered torrc file into '$tmp_src'"
    msg green "     If something goes wrong attempting to install it, you can try installing the above file by hand."
    msg
    safe_copy_file "$tmp_src" "$to_file"
    # If successful, then we can remove the temporary file
    rm "$tmp_src"
}

