# RaspiAsteriskAlexa

RaspiAsteriskAlexa is a proof-of-concept Asterisk AGI integration for sending
telephone audio to Amazon Alexa Voice Service (AVS) and playing the returned
audio.

## Project status

This repository originated in 2016 and uses the legacy AVS
`/v1/avs/speechrecognizer/recognize` endpoint. Amazon's current AVS integrations
use newer protocols and product requirements. Treat this project as
experimental code, not as a supported or certifiable Alexa client.

Before investing in deployment, confirm that the legacy endpoint is still
enabled for your AVS product and region. A production migration should use
Amazon's current AVS Device SDK and authorization guidance:

- <https://developer.amazon.com/en-US/docs/alexa/alexa-voice-service/>
- <https://developer.amazon.com/en-US/docs/alexa/alexa-voice-service/authorize-cbl.html>
- <https://github.com/alexa/avs-device-sdk>

Do not expose the Alexa extension through a public telephone number. Voice
audio is sent to Amazon for processing, and use remains subject to Amazon's
agreements and privacy requirements.

## Security changes

The current version removes credentials from source files and no longer writes
bearer tokens, OAuth responses, recordings, or request commands to predictable
files in `/tmp`.

- Credentials live in `/etc/asterisk/alexa.conf`.
- The configuration is expected to be `root:asterisk` and mode `0640`.
- Access tokens are cached with expiry information under
  `/var/cache/asterisk-alexa`.
- Token refresh is serialized with `flock` and occurs only near expiration.
- AGI request files use a private per-call temporary directory and are removed
  automatically.
- External commands are executed without a shell, and their exit status is
  checked.
- AVS multipart responses are parsed as MIME rather than split on byte strings.
- The phone example uses authenticated PJSIP with a local-network ACL.

Existing installations that contain credentials in `token.pl`,
`grant_token.sh`, `/tmp/request.dat`, or `/tmp/token.*` should rotate the
affected Login with Amazon client secret and refresh token.

## Requirements

- A currently supported Raspberry Pi OS release
- Asterisk with PJSIP
- Perl 5.36 or newer
- `curl`
- SoX with MP3 support
- An Amazon developer account and registered AVS product
- A trusted local SIP phone or softphone

The installer uses only Raspberry Pi OS/Debian packages. It does not download
and execute CPAN bootstrap scripts.

## Installation

Review the installer before running it:

```sh
sudo apt-get install git
git clone https://github.com/rgrokett/RaspiAsteriskAlexa.git
cd RaspiAsteriskAlexa
bash ./install.sh
```

The installer:

- installs the required Debian packages;
- installs `alexa.agi` in the detected Asterisk AGI directory;
- installs `token.pl` in `/usr/local/libexec/asterisk-alexa`;
- installs prompts in the Asterisk custom sounds directory;
- creates `/var/cache/asterisk-alexa` for the `asterisk` user; and
- creates `/etc/asterisk/alexa.conf` only when it does not already exist.

The following environment variables can override paths and ownership:

```text
ASTERISK_USER
ASTERISK_GROUP
ASTERISK_ETC_DIR
AGI_DIR
SOUNDS_DIR
ALEXA_LIBEXEC_DIR
```

## Credentials

Edit `/etc/asterisk/alexa.conf`:

```sh
sudoedit /etc/asterisk/alexa.conf
```

Set at least:

```ini
client_id=YOUR_LOGIN_WITH_AMAZON_CLIENT_ID
client_secret=YOUR_LOGIN_WITH_AMAZON_CLIENT_SECRET
refresh_token=YOUR_REFRESH_TOKEN
```

Protect and validate the file:

```sh
sudo chown root:asterisk /etc/asterisk/alexa.conf
sudo chmod 0640 /etc/asterisk/alexa.conf
sudo -u asterisk /usr/local/libexec/asterisk-alexa/token.pl --check-config
```

To exchange a newly issued authorization code, first populate `client_id` and
`client_secret`, then run:

```sh
./grant_token.sh
```

The helper stores the returned refresh token in the protected configuration.
The wrapper reads the short-lived authorization code from a hidden prompt so it
is not retained in shell history or exposed as a process argument.

Test access-token retrieval without displaying the token:

```sh
sudo -u asterisk \
  /usr/local/libexec/asterisk-alexa/token.pl --force-refresh
```

## Asterisk configuration

Back up the existing Asterisk configuration before merging examples.

1. Adapt and merge [`config/pjsip.conf`](config/pjsip.conf) into
   `/etc/asterisk/pjsip.conf`.
2. Replace the example password with a long random value.
3. Restrict the ACL to the actual trusted LAN.
4. Merge [`config/extensions.conf`](config/extensions.conf) into
   `/etc/asterisk/extensions.conf`.
5. Add `include => alexa_tts` only to the trusted local dialplan context.
6. Reload PJSIP and the dialplan.

Example reload commands:

```sh
sudo asterisk -rx 'pjsip reload'
sudo asterisk -rx 'dialplan reload'
```

Do not use the old unauthenticated `chan_sip` example from the historical PDF.
`chan_sip` is deprecated and the original example used no password.

## Operation

Dial extension `5555` from the trusted local endpoint. The AGI helper:

1. records up to 30 seconds, ending after two seconds of silence;
2. obtains a cached or refreshed access token;
3. converts the recording to the AVS input format;
4. sends the request over TLS;
5. parses the multipart AVS response;
6. converts the MPEG response to Asterisk signed linear audio; and
7. plays the response before prompting for another question.

The dialplan no longer refreshes a token through `System()` on every call.

## Troubleshooting

Compile and test the local files:

```sh
prove -v t
perl -c alexa.agi
perl -c token.pl
bash -n install.sh grant_token.sh
```

Enable AGI logging temporarily:

```sh
sudo -u asterisk env ALEXA_DEBUG=1 \
  /usr/local/libexec/asterisk-alexa/token.pl --check-config
sudo asterisk -rx 'agi set debug on'
```

Useful checks:

```sh
sudo -u asterisk test -r /etc/asterisk/alexa.conf
sudo -u asterisk test -w /var/cache/asterisk-alexa
sudo -u asterisk \
  /usr/local/libexec/asterisk-alexa/token.pl --force-refresh
sudo asterisk -rx 'pjsip show endpoints'
```

If OAuth succeeds but AVS rejects the speech request, verify the registered AVS
product, region, endpoint availability, and current Amazon protocol
requirements. The legacy API is the primary compatibility risk.

The bundled `RaspiAsteriskAlexaInstallation.pdf` is retained as historical
documentation. Its Jessie, `chan_sip`, blank-password, source-embedded
credential, CPAN bootstrap, and predictable `/tmp` instructions are obsolete.

## License

GPL-2.0. See [`LICENSE`](LICENSE).
