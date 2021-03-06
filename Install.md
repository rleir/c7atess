I have been installing the Catalyst app in /var/lib/catalyst/ocr.  

Installation:
  Untar or clone to a directory of your choosing (I like /var/lib/catalyst/OCR).
    DoJob.pl
    DoImage.pl
    OCR/Ocrdb.pm
    OCR/hocrUtils.pm
    root/*
    lib/*
    inc/*
    ocr.conf

To start the Scheduler, run
  cd /var/lib/catalyst/OCR ; \
  ./DoJob.pl --startScheduler ; \

To start the web control panel, run (if you want to use port 3333)
  cd /var/lib/catalyst/OCR ; \
  ./script/ocr_server.pl -p3333 --verbose --debug

Note: 
Many CPAN modules need to be installed. When you do this, please would you note the cpanm commands
needed and contribute this to the project?  For master and worker. And note your Linux distro.
Check that you have all needed modules by saying './DoJob.pl' with no parameters. Likewise with the other .pl scripts.

Install needed modules:
  sudo cpanm Getopt::Long
  sudo cpanm File::Touch
  sudo cpanm Email::Sender::Simple
  ++

If you have not installed cpanm, look at https://github.com/miyagawa/cpanminus
Quickstart: Run the following command to install it
  curl -L https://cpanmin.us | perl - --sudo App::cpanminus
or
  sudo curl -L https://cpanmin.us | perl - App::cpanminus

Installation on a worker machine is by installWorker.sh.
This is pushed to a worker machine by pushWorker.sh. 
The master machine can also be a worker, so run installWorker.sh there too.


DataBase config:

Mysql needs to be configured by saying something like:
 $ mysql -hsnap -Dmydb -uocruser -p < ocrResults.sql

This assumes the MySQL server is on the host 'snap', and the user 'ocruser' has table create privileges.
There is friendly MySQL help at https://codex.wordpress.org/Installing_WordPress#Using_the_MySQL_Client

In /etc/ocr/db.ini, normally we have 
  [DBconn]
  hostname=snap.example.org

or 
  [DBconn]
  hostname=yb.example.org

However, in the special case where the OCR database machine is also an OCR worker machine, we need:
  [DBconn]
  hostname=localmysql



Worker log dir: The installation created a directory /var/log/ocr/ in each worker machine
 which is writeable by the user running this cat app. Log rotation on this is in 
 /etc/logrotate.d/ocr (correct the user,group). With log rotation, it becomes
 easy to compare the performance of the worker computers 'wc -l /var/log/ocr/*.log'.

/var/log/ocr/*.log {
	daily
	missingok
	rotate 52
	create 644 richard adm
}


==========================
