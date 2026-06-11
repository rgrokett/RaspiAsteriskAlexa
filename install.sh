#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly ASTERISK_USER="${ASTERISK_USER:-asterisk}"
readonly ASTERISK_GROUP="${ASTERISK_GROUP:-asterisk}"
readonly ASTERISK_ETC_DIR="${ASTERISK_ETC_DIR:-/etc/asterisk}"
readonly ALEXA_LIBEXEC_DIR="${ALEXA_LIBEXEC_DIR:-/usr/local/libexec/asterisk-alexa}"
readonly ALEXA_CACHE_DIR="/var/cache/asterisk-alexa"

if [[ -d /var/lib/asterisk/agi-bin ]]; then
    readonly AGI_DIR="${AGI_DIR:-/var/lib/asterisk/agi-bin}"
    readonly SOUNDS_DIR="${SOUNDS_DIR:-/var/lib/asterisk/sounds}"
else
    readonly AGI_DIR="${AGI_DIR:-/usr/share/asterisk/agi-bin}"
    readonly SOUNDS_DIR="${SOUNDS_DIR:-/usr/share/asterisk/sounds}"
fi

sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    libemail-mime-perl \
    libio-socket-ssl-perl \
    libjson-perl \
    libsox-fmt-mp3 \
    sox

sudo install -d -o "$ASTERISK_USER" -g "$ASTERISK_GROUP" -m 0750 \
    "$AGI_DIR" \
    "$AGI_DIR/AsteriskAlexa" \
    "$SOUNDS_DIR/custom" \
    "$ALEXA_CACHE_DIR"
sudo install -d -o root -g "$ASTERISK_GROUP" -m 0750 \
    "$ALEXA_LIBEXEC_DIR"

sudo install -o root -g "$ASTERISK_GROUP" -m 0750 \
    "$SCRIPT_DIR/alexa.agi" \
    "$AGI_DIR/alexa.agi"
sudo install -o root -g "$ASTERISK_GROUP" -m 0644 \
    "$SCRIPT_DIR/lib/AsteriskAlexa/Multipart.pm" \
    "$AGI_DIR/AsteriskAlexa/Multipart.pm"
sudo install -o root -g "$ASTERISK_GROUP" -m 0750 \
    "$SCRIPT_DIR/token.pl" \
    "$ALEXA_LIBEXEC_DIR/token.pl"
sudo install -o root -g "$ASTERISK_GROUP" -m 0644 \
    "$SCRIPT_DIR/avs_audio.json" \
    "$ASTERISK_ETC_DIR/avs_audio.json"
sudo install -o "$ASTERISK_USER" -g "$ASTERISK_GROUP" -m 0644 \
    "$SCRIPT_DIR"/sounds/alexa*.sln \
    "$SOUNDS_DIR/custom/"

if [[ ! -e "$ASTERISK_ETC_DIR/alexa.conf" ]]; then
    sudo install -o root -g "$ASTERISK_GROUP" -m 0640 \
        "$SCRIPT_DIR/config/alexa.conf.example" \
        "$ASTERISK_ETC_DIR/alexa.conf"
    printf 'Created %s; add your Login with Amazon credentials before use.\n' \
        "$ASTERISK_ETC_DIR/alexa.conf"
else
    printf 'Preserved existing configuration: %s\n' \
        "$ASTERISK_ETC_DIR/alexa.conf"
fi

printf 'Installation complete.\n'
printf 'Validate credentials with:\n'
printf '  sudo -u %s %s/token.pl --check-config\n' \
    "$ASTERISK_USER" \
    "$ALEXA_LIBEXEC_DIR"
