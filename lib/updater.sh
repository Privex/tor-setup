#!/usr/bin/env bash

if [ -z ${TORSETUP_DIR+x} ]; then
    _DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    grep -q "/lib" <<< "$_DIR" && TORSETUP_DIR=$(dirname "$_DIR") || TORSETUP_DIR="$_DIR"
fi

[ ! -z ${TORSETUP_FUNCS_LOADED+x} ] || source "${TORSETUP_DIR}/lib/functions.sh" || { 
    >&2 echo "${BOLD}${RED}[lib/updater.sh] CRITICAL ERROR: Could not load functions file at '${TORSETUP_DIR}/lib/functions.sh' - Exiting!${RESET}"
    exit 1
}

TORSETUP_UPDATER_LOADED='y'     # Used to detect if this file has already been sourced or not

: ${TORSETUP_UPDATE_FILE="$HOME/.torsetup_last_update"}
: ${TORSETUP_UPDATE_SECS=604800}
: ${TORSETUP_LAST_UPDATE=0}

update_torsetup() {
    cd "$TORSETUP_DIR"
    if ! can_write "$TORSETUP_DIR"; then
        if sudo_works; then
            msg yellow " [?] TorSetup install folder not writable by this user, but sudo appears to work."
            local git_url=$(sudo git remote get-url origin)
            msg yellow " [lib/updater.sh] (SUDO) Downloading TorSetup updates from Git: $git_url"
            sudo git reset --hard > /dev/null
            sudo git pull -q -f > /dev/null
        else
            msg bold red " [!!!] The TorSetup installation folder '$TORSETUP_DIR' is not writable, and passwordless sudo is unavailable."
            msg red " [!!!] Skipping update for now. "
        fi
    else
        local git_url=$(git remote get-url origin)
        msg yellow "[lib/updater.sh] Downloading TorSetup updates from Git: $git_url"
        git reset --hard > /dev/null
        git pull -q -f > /dev/null
    fi
    msg
    date +'%s' > "$TORSETUP_UPDATE_FILE"
}

last_update_torsetup() {
    if [[ -f "$TORSETUP_UPDATE_FILE" ]]; then
        local ts_lst=$(cat "$TORSETUP_UPDATE_FILE")
        TORSETUP_LAST_UPDATE=$(($ts_lst))
    fi
}

autoupdate_torsetup() {
    last_update_torsetup
    local unix_now=$(($(date +'%s'))) next_update=$((TORSETUP_LAST_UPDATE+TORSETUP_UPDATE_SECS))
    local last_rel=$((unix_now-TORSETUP_LAST_UPDATE))
    if (($next_update<$unix_now)); then
        msg green " [+] Last update was $last_rel seconds ago. Auto-updating Privex TorSetup..."
        update_torsetup
    else
        _debug yellow "Auto-update requested, but last update was $last_rel seconds ago (next update due after ${TORSETUP_UPDATE_SECS} seconds)"
    fi
}
