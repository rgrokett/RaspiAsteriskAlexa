#!/bin/bash
# Simplistic install script
# and install your tokens
# This doesn't check for errors, but can be run multiple times safely

sudo cp alexa.agi /usr/share/asterisk/agi-bin/alexa.agi
sudo cp avs_audio.json /etc/
sudo cp sounds/alexa*.sln /usr/share/asterisk/sounds/custom/

sudo chown asterisk:asterisk /usr/share/asterisk/agi-bin/alexa.agi
sudo chown asterisk:asterisk /etc/avs_audio.json
sudo chown asterisk:asterisk /usr/share/asterisk/sounds/custom/alexa*.sln

cp token.pl /home/pi
sudo rm -f /tmp/token.* /tmp/avs* 

# INSTALL VARIOUS PACKAGES
sudo apt-get -y install sox
sudo apt-get -y install libsox-fmt-mp3
sudo apt-get -y install libwww-perl libjson-perl
sudo apt-get -y install flac
sudo curl -L http://cpanmin.us | perl - --sudo App::cpanminus
sudo cpanm IO::Socket::SSL --force
sudo perl -MCPAN -e 'install JSON'
sudo apt-get -y install libjson-pp-perl

echo "FINISHED"
echo

