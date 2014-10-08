#!/bin/bash
#
# Installs an OCR worker server. 
# Copies programs to the server, and installs packages there.
# Future: do this all with Puppet.
#
# Note! you need to first get the ssh key installed on the server
# so that the scp's will work without a password.
#
# Note! you need to first log into the server and edit the
# /etc/sudoers config, or sudo will ask for a password when
# it gets to the 'sudo' line below. This sudo config change will be overwritten by Puppet in 10 minutes or so.
#
# add the NOPASSWD flag.
# $ sudo vi /etc/sudoers
# richard OCRSERVERS=(ALL) ALL
# changed to
# richard OCRSERVERS=(ALL) NOPASSWD:ALL

#
# Note! This all works in the richard account on all servers. Except that it is rleir on the Arundel desktop PC.

# todo: automate this
# GRANT ALL PRIVILEGES ON mydb.* to "ocruser"@"aragon.office.c7a.ca" IDENTIFIED BY "whydidu"; FLUSH PRIVILEGES;

#set -x
scp ~/ocr/pdfocr/c7atess.pl richard\@$1\:

scp ~/ocr/pdfocr/Ocrdb.pm richard\@$1\:

scp installWorker.sh richard\@$1\:

ssh richard\@$1   sudo ./installWorker.sh
#ssh richard\@$1   sudo -A ~/apass ./installWorker.sh
