#!/usr/bin/perl
#
# This hack just looks for a SIP that has not been OCR'd.
# But not in a smart way.



#
# check for anything in DB
# if no image was done in DB
#   queue a job
#
# $0 3 gives us
# /collections.new/pool?/aip/oocihm/300
# /collections.new/pool?/aip/oocihm/301
# ..

use strict;
use warnings;
use diagnostics;


use File::Find::Rule;
use Getopt::Long;
use Cwd 'abs_path';

use OCR::Ocrdb qw( pushOCRjob);
use Config::IniFiles;
use DBI;
use DBI qw(:sql_types );
use Carp;
use Data::Dumper;

sub push_to_queue {
    my ( $abspath) = @_;

    my $priority = 5;  
    my $notify   = 'richard@c7a.ca';
    my $data = abs_path(  $abspath );
    print Dumper($data);

    my $starttime = time();
    my $collID = "dummysipspec";

    # queue a job
    my $ret = pushOCRjob( "NNN", 
                          $priority, 
                          $notify,
                          $data, 
                          " ./DoImage.pl --input={} --lang=eng --verbose ", 
                          $starttime,
                          $collID );
    return $ret;
}

my $filesystem1 = "/collections.new/pool1/aip/";
my $filesystem2 = "/collections.new/pool2/aip/";

my $input  = ".";
my $startnum = 99; # default is invalid, so the parm is requirde
my $help;
my $result = GetOptions (
                    "input=s"    => \$input,     # string
                    "startnum=n" => \$startnum,     # int 0 .. 9
                    "help"       => \$help);  # flag
if( $help || $startnum == 99) {
    warn "Usage $0 [--startnum=n] --verbose\n";
    warn "      startnum is int 0 .. 9    \n";
    warn "or    $0 --help\n";
    exit 0;
}

my $cSQL =<<EOS2;
select  imageFile, count(*) as count from ocr where imageFile like ? ;
EOS2

my $cfg = Config::IniFiles->new( -file => "/etc/ocr/db.ini" );
my $username = $cfg->val( 'DBconn', 'username' ) ;
my $password = $cfg->val( 'DBconn', 'password' ) ;
my $hostname = $cfg->val( 'DBconn', 'hostname' ) ;
my $dbname   = $cfg->val( 'DBconn', 'dbname' ) ;

my $dbh = DBI->connect( "DBI:mysql:database=$dbname;host=$hostname", $username, $password,
                        {RaiseError => 0, PrintError => 0, mysql_enable_utf8 => 1}
    )
    or croak "Could not connect to database: $DBI::errstr" ;

my $iter  = $startnum * 100;
my $limit = $iter + 100; 

while ( $iter < $limit ) {

    my $iter00 = sprintf("%03d", $iter);
    $iter++;
    my $dirprefix = "oocihm/$iter00";
    print Dumper($dirprefix);

    my $directory = $filesystem2 . $dirprefix;
    print Dumper($directory);
    # find all the subdirectories of a given directory
    #ls -l oocihm/677
    #ls -l  $filesystem . $dirprefix
    #for each, is there at least one result? (later, look for the correct number of results)
    #  if not, queue the dir
    opendir (DIR, $directory) or die $!;
    while (my $file = readdir(DIR)) {
        if( $file eq  '.') { next };
        if( $file eq '..') { next };

        # get a count of items from DB
        my $sth = $dbh->prepare($cSQL)   or croak $dbh->errstr;

        # remove prefix
        # /collections.new/pool1/aip/oocihm/40
        # becomes                    oocihm/40
        print                                 $directory . '/' . "$file\n";

        my $like_term =  $dirprefix .  '/' . $file . '%';
        print "searching for  $like_term \n";

        $sth->bind_param(1, $like_term);
        my $rv = $sth->execute( )  or croak $sth->errstr; # this can be slow, it is scanning the DB
        my $rows = $sth->rows;
     
        my $row = $sth->fetchrow_hashref;

        my $count = @$row{'ocr','count'};
        $sth->finish;

        if( $count) {
            print "found $count for      $like_term ========== \n";
        } else {
            print "found $count, pushing $like_term ++++++++ \n";
            my $ret = push_to_queue(  $filesystem2 . $dirprefix . '/' . $file);
        }
    }
    closedir( DIR);
}
$dbh->disconnect();

exit 1;


