#!/bin/bash
# This is normally invoked by the pushWorker.sh script.
#
# Installs an OCR worker server. 
# Copies programs to the server, and installs packages there.
# Future: do this all with Puppet.

apt-get -y install emacs23-nox
apt-get -y install libstring-crc32-perl
apt-get -y install nfs-common parallel libyaml-perl perl-doc make
apt-get -y install tesseract-ocr
apt-get -y install tesseract-ocr-fra
apt-get -y install tesseract-ocr-eng
apt-get -y install tesseract-ocr-ita
apt-get -y install libhtml-format-perl
apt-get -y install libconfig-inifiles-perl
apt-get -y install libdbi-perl
apt-get -y install libdbd-mysql-perl
apt-get -y install libgraphics-magick-perl
# or perlmagick for ImageMagick

# Cpan: when running cpan for the first time,
# accept all recommendations
PERL_MM_USE_DEFAULT=1 cpan -i  HTML::TagParser

mkdir -p /etc/c7aocr
cat > /etc/c7aocr/tessdb.ini <<EOF
[DBconn]
hostname=arundel
dbname=mydb
username=ocruser
password=whydidu

[DB]
tablename=ocr

EOF

echo  "192.168.1.169:/cihmz1/collections /collections   nfs4 ro,auto,soft,intr,nolock,nodev,nosuid,async,noacl,noatime,nodiratime  2 2" >> /etc/fstab

mkdir -p /collections
chown richard:users /collections

# if you install a second time, the following line will fail
mount /collections

echo  "192.168.1.131   arundel " >> /etc/hosts


# end

