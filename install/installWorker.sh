#!/bin/bash
# This is normally invoked by the pushWorker.sh script.
#
# Installs an OCR worker server. 
# Copies programs to the server, and installs packages there.
# Future: a new c7aocr user account, not richard
# Future: do this all with Puppet.

# Install Ubuntu 14.04 packages
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

apt-get install libxml2-dev
apt-get install zlib1g-dev

# or perlmagick for ImageMagick

# Install a Perl module from CPAN
# Cpan: when running cpan for the first time,
# accept all recommendations
PERL_MM_USE_DEFAULT=1 cpan -i  HTML::TagParser
PERL_MM_USE_DEFAULT=1 cpan -i  common::sense
PERL_MM_USE_DEFAULT=1 cpan -i  XML::LibXML::PrettyPrint

# create config files
mkdir -p /etc/c7aocr
cat > /etc/c7aocr/tessdb.ini <<EOF
[DBconn]
hostname=yb.office.c7a.ca
dbname=ocrResults
username=ocruser
password=whydidu

[DB]
tablename=ocr

EOF

# Logfile rotation
mkdir /var/log/c7aocr
chown richard /var/log/c7aocr
cat > /etc/logrotate.d/c7aocr <<EOF
/var/log/c7aocr/*.log {
	daily
	missingok
	rotate 52
	create 644 richard adm
}
EOF

# mount the TDR by NFS
echo  "192.168.1.169:/cihmz1/repository /collections.new/pool1   nfs4 ro,auto,soft,intr,nolock,nodev,nosuid,async,noacl,noatime,nodiratime  2 2" >> /etc/fstab
echo  "192.168.1.169:/cihmz2/repository /collections.new/pool2   nfs4 ro,auto,soft,intr,nolock,nodev,nosuid,async,noacl,noatime,nodiratime  2 2" >> /etc/fstab

mkdir -p /collections
mkdir -p /collections.new/pool1
mkdir -p /collections.new/pool2
chown richard:users /collections
chown -R richard:users /collections.new

# if you install a second time, the following lines will fail
mount /collections.new/pool1
mount /collections.new/pool2

ln -s /collections.new/pool1/aip /collections/tdr

echo  "192.168.1.131   arundel " >> /etc/hosts

mkdir           CIHM
mv Ocrdb.pm     CIHM/
mv hocrUtils.pm CIHM/

# end

