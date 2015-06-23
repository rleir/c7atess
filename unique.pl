#!/usr/bin/perl
#
# for all DB recs in input, de-duplicate
# read in a flat file created with 
#   mysql -e "select idocr, imageFile, count(*) as ct from ocr group by imageFile HAVING ct > 1;" > nonunique.d
#
# sample:
# 103513	oocihm/003/oocihm.39229/data/sip/data/files/oocihm.39229.10.jp2	2
# 103531	oocihm/003/oocihm.39229/data/sip/data/files/oocihm.39229.11.jp2	2

use strict;
use warnings;
use diagnostics;
use DBI;

use Config::IniFiles;
use Carp;
use Data::Dumper;

my $cfg = Config::IniFiles->new( -file => "/etc/c7aocr/tessdb.ini" );
my $username = $cfg->val( 'DBconn', 'username' ) ;
my $password = $cfg->val( 'DBconn', 'password' ) ;
my $hostname = $cfg->val( 'DBconn', 'hostname' ) ;
my $dbname   = $cfg->val( 'DBconn', 'dbname' ) ;

# delete
my $dsql =<<EOS;
delete from ocr where imagefile= ? and idocr= ?
EOS

# count them
my $csql =<<EOS2;
select min(idocr) as idid, imageFile, count(*) as ccoouunntt from ocr where imagefile= ? 
EOS2

my $dbh = DBI->connect( "DBI:mysql:database=$dbname;host=$hostname", $username, $password,
                        {RaiseError => 0, PrintError => 0, mysql_enable_utf8 => 1}
    )
    or croak "Could not connect to database: $DBI::errstr" ;

my $file = "nonunique.d";
open(my $data, '<', $file) or die "Could not open '$file' $!\n";
 
while (my $line = <$data>) {
    chomp $line;

    $line =~ /([0-9]+)\s+([^ ]+)\s+([1-6])/;
    my ($id, $imageFile, $count) = ("no", "no", "no"); 
    ( $id, $imageFile, $count) = ( $1, $2, $3); 

    print "$id $imageFile $count \n";

    # note: $count comes from the input, then changes to the DB count
    while( $count > 1) {

        # count what is currently in the DB
        my $sth = $dbh->prepare($csql)   or croak $dbh->errstr;
        my $rv = $sth->execute( $imageFile)  or croak $sth->errstr;
        my $rows = $sth->rows;
     
        my $row = $sth->fetchrow_hashref;
        #    print Dumper($row);

        $count = @$row{'ocr','ccoouunntt'};
        $id    = @$row{'ocr','idid'};
        my $rc   = $sth->finish;

        #    print "4id $id count $count $imageFile \n";

        if( $count > 1) {
            # del the one with the lowest id
            $sth = $dbh->prepare($dsql)   or croak $dbh->errstr;
            $rv = $sth->execute( $imageFile, $id)  or croak $sth->errstr;
            $rc   = $sth->finish;
            print "5id $id count $count $imageFile \n";
        }
    }
}
$dbh->disconnect();
exit 1;


