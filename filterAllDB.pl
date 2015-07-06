#!/usr/bin/perl
#
# for all DB records, run the filter
#
# for all aips in ocrdb (parallel)
#   http://stackoverflow.com/questions/11503393/mysql-group-by-substring
#   filter all images
#   if missing then do ocr ??
#   if 3 seq missing 
#      stop this aip
# 
# or
# for all images in ocrdb (parallel) (limit 100, advance) "SELECT * FROM Orders LIMIT 10 OFFSET 15";
#  "SELECT outputHocr FROM ocr LIMIT 1 OFFSET ?"; 0 ..
#   get old stats
#   filter image
#   report new and old stats
# 
# 

use strict;
use warnings;
use diagnostics;
use Getopt::Long;
#use OCR::Ocrdb qw( existsOCR insertOCR getOCR);
use Config::IniFiles;
use DBI;
use DBI qw(:sql_types );
use Carp;
use IO::Compress::Gzip qw(gzip $GzipError) ;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError) ;

use OCR::hocrUtils qw( hocr2words doFilterHocr);

use constant { TRUE => 1, FALSE => 0 };

##############################################
# Mainline
#

my $cSQL =<<EOS2;
select idocr, avgWordConfidence, numWords, outputHocr from ocr limit 1 offset ? ; 
EOS2

my $uSQL =<<EOS3;
update ocr set avgWordConfidence=?, numWords=?, outputHocr=?, outputText=?, zzz where idocr = ? ; 
EOS3

my $cfg = Config::IniFiles->new( -file => "/etc/ocr/db.ini" );
my $username = $cfg->val( 'DBconn', 'username' ) ;
my $password = $cfg->val( 'DBconn', 'password' ) ;
my $hostname = $cfg->val( 'DBconn', 'hostname' ) ;
my $dbname   = $cfg->val( 'DBconn', 'dbname' ) ;

my $dbh = DBI->connect( "DBI:mysql:database=$dbname;host=$hostname", $username, $password,
                        {RaiseError => 0, PrintError => 0, mysql_enable_utf8 => 1}
    )
    or croak "Could not connect to database: $DBI::errstr" ;

warn "program will end with a DB error when all rows have been done \n";
my $offset = 0;
my $loops = 0;
while( 1) {

    # get an item from DB
    my $sth = $dbh->prepare($cSQL)   or croak $dbh->errstr;

    $sth->bind_param(1, $offset, SQL_INTEGER);
    my $rv = $sth->execute( )  or croak $sth->errstr; # this is the program exit
    my $rows = $sth->rows;
     
    my $row = $sth->fetchrow_hashref;
        #    print Dumper($row);

    my $idocr = @$row{'ocr','idocr'};
    my $avgWordConfidence = @$row{'ocr','avgWordConfidence'};
    my $numWords = @$row{'ocr','numWords'};
    my $gzDBhocr = @$row{'ocr','outputHocr'};
    $sth->finish;

    if( ! $gzDBhocr) {
        die "item not found, offset= $offset \n";
    }

    # uncompress it (this needs bytes, not utf-8)
    my $rawhocr ;
    my $status = gunzip \$gzDBhocr, \$rawhocr 
        or die "gunzip failed: $GunzipError\n";

    my $filtered = doFilterHocr ( $rawhocr);

    # get some stats and text from the .hocr file
    my ($newAvgWordConfidence, $newNumWords, $newNumWords2, $unformattedtext, $diagnostic) = hocr2words( $filtered);
    if ( $diagnostic) {
        warn $diagnostic;

    } else {
        # compress hocr
        my $gzhocr = "";
        gzip \$filtered, \$gzhocr 
            or die "gzip failed: $GzipError\n";

        $sth = $dbh->prepare($uSQL)   or croak $dbh->errstr;
        $rv = $sth->execute( $idocr, $newAvgWordConfidence, $newNumWords, $gzhocr, $unformattedtext )
            or croak $sth->errstr;
        $sth->finish;
        print "offset $offset $loops $idocr conf $avgWordConfidence $newAvgWordConfidence " . 
            "nwords $numWords new $newNumWords $newNumWords2 \r";
    }
    $loops++;
    $offset++;
    last;
}
$dbh->disconnect();

exit 1;


