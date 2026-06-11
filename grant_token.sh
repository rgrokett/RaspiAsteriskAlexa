#!/usr/bin/env bash

set -euo pipefail

readonly TOKEN_HELPER="${TOKEN_HELPER:-/usr/local/libexec/asterisk-alexa/token.pl}"
readonly CONFIG_FILE="${ALEXA_CONFIG:-/etc/asterisk/alexa.conf}"

if [[ $# -ne 0 ]]; then
    printf 'Usage: %s\n' "$0" >&2
    exit 64
fi

read -r -s -p 'Authorization code: ' authorization_code
printf '\n'

if [[ -z "$authorization_code" ]]; then
    printf 'Authorization code cannot be empty.\n' >&2
    exit 64
fi

printf '%s\n' "$authorization_code" |
    sudo "$TOKEN_HELPER" \
        --config "$CONFIG_FILE" \
        --exchange-code
