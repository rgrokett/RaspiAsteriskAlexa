# RaspiAsteriskAlexa
Integrating Asterisk with Amazon Alexa Voice Service on a Raspberry Pi Zero using AGI

Important Note: This can only be used as a proof-of-concept. It currently does not meet the Amazon Voice Service Agreement for Public or Commercial application. See https://developer.amazon.com/edw/avs_agreement.html for more details.  
It does meet requirements for home or experimental (private) use. To keep it private, the Asterisk configuration files here default to an internal Asterisk extension only.

# Overview
This requires an account with Amazon and Amazon Voice Services:
https://developer.amazon.com/public/solutions/alexa/alexa-voice-service

Also required is:
  Raspberry Pi (Zero, B+, 3, etc.) running Raspian Jessie (or newer)
  Asterisk PBX  ( $ sudo apt-get install asterisk ) 
  A bunch of packages (see the Installation document in Github)
  The files from Github
  Your Voice Service authorized in Amazon Voice Services
  https://developer.amazon.com/public/solutions/alexa/alexa-voice-service/docs/authorizing-your-alexa-enabled-product-from-a-website
  (This solution uses Amazon Implicit Grant method of authentication so follow only its steps.)
  
Note that the Amazon Authorization is the most complicated part of this project. See Installation doc for details.


  


