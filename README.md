# RaspiAsteriskAlexa
Integrating Asterisk with Amazon Alexa Voice Service on a Raspberry Pi Zero using AGI

Important Note: This can only be used as a proof-of-concept. It currently does not meet the Amazon Voice Service Agreement for Public or Commercial application. See https://developer.amazon.com/support/legal/alexa/alexa-voice-service/terms-and-agreements for more details.  
It does meet requirements for home or experimental (private) use. To keep it private, the Asterisk configuration files here default to an internal Asterisk extension only.

Also available: Google Voice Assistant running on Asterisk PBX on a Pi.  https://github.com/rgrokett/RaspiAsteriskGoogle

Note that Amazon changes SDK and security req often, may cause issues here.

---
**2021 Update:** Incredible PBX for Asterisk has added this feature and updated for easier installation!
Go to: 
https://nerdvittles.com/amazons-alexa-now-available-for-incredible-pbx-2020/
---

# Overview
This requires an account with Amazon and Amazon Voice Services:
https://developer.amazon.com/public/solutions/alexa/alexa-voice-service

Also required is:
+ Raspberry Pi (Zero, B+, 3, etc.) running Raspian Jessie (or newer)
+ Asterisk PBX  ( $ sudo apt-get install asterisk ) 
+ A bunch of packages (see the Installation document in Github)
+ The files from Github
+ Your Voice Service authorized in Amazon Voice Services
+ https://developer.amazon.com/en-US/docs/alexa/alexa-voice-service/authorize-cbl.html
+ (This solution uses Amazon Implicit Grant method of authentication so follow only its steps.)
  
Note that the Amazon Authorization is the most complicated part of this project. See Installation doc for details.


  
# Alternate RasPBX (FreePBX) Usage
If you are a FreePBX (RasPBX) user, you can apply the following changes as shown from jimbolaya:

*jimbolaya commented:

I got this running on RasPBX. I skipped the sections until I got to "Alexa/Asterisk Install and Configuration" since I already had a running setup on RasPBX.

I ran install.sh from /usr/src/RaspiAsteriskAlexa. I probably should have just done it by hand.
In the instructions I replaced "/usr/share" with "/var/lib" which is where the asterisk sound directory and the agi-bin directory reside. This includes a path within .../asterisk/agi-bin/alexa.agi

There is no .../sounds/custom directory, so I had to create that with appropriate permissions.

For setting up the "AMAZON ALEXA VOICE" extension, the file for the custom extension is different. In FreePBX, the custom extensions live in "/etc/asterisk/extensions_custom.conf". I added the [alexa_tts] to this file and:

    [ext-local-custom]
    include => alexa_tts
    below the [alexa_tts] section

RasPBX doesn't seem to have a pi user, but that doesn't seem to be needed. I did create one anyway and copied the RaspiAsteriskAlexa directory there just in case.

