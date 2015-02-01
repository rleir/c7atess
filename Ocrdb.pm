# DB access for the ocr table
#   for insert, check record

package Ocrdb;

use strict;
use warnings;
use diagnostics;

# warn user (from perspective of caller)
use Carp;

# MooseX::SimpleConfig
# MooseX::Getopt
use Config::IniFiles;
use DBI;

use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION); #  %EXPORT_TAGS
use Exporter;
$VERSION = 0.98;
@ISA = qw(Exporter);
@EXPORT = qw( existsOCR insertOCR getOCR);

my $logFile;

my $cfg = Config::IniFiles->new( -file => "/etc/c7aocr/tessdb.ini" );
my $username = $cfg->val( 'DBconn', 'username' ) ;
my $password = $cfg->val( 'DBconn', 'password' ) ;
my $hostname = $cfg->val( 'DBconn', 'hostname' ) ;
my $dbname   = $cfg->val( 'DBconn', 'dbname' ) ;

open($logFile, '>>', "/tmp/testtess.log")
    || croak "LOG open failed: $!";
my $oldfh = select($logFile); $| = 1; select($oldfh);

my $SQLexist = <<ENDSTAT1;
SELECT idocr 
FROM ocr 
WHERE 
    imageFile = ?
AND
    ocrEngine = ?
AND
    langParam = ?
ENDSTAT1
#AND
#    brightness = ?

my $SQLexistAny = <<ENDSTAT11;
SELECT idocr 
FROM ocr 
WHERE 
    imageFile = ?
AND
    langParam = ?
ENDSTAT11
#AND
#    brightness = ?



# check for the existence of a tuple
sub existsOCR {
    my ( $file, $engine, $lang) =  @_;
    my $dbh = DBI->connect( "DBI:mysql:database=$dbname;host=$hostname", $username, $password,
			    {RaiseError => 0, PrintError => 0, mysql_enable_utf8 => 1}
	)
	or croak "Could not connect to database: $DBI::errstr" ;
    my $sth;
    if( !defined ($engine)) {
	# any engine
	$sth = $dbh->prepare($SQLexistAny)   or croak $dbh->errstr;
	my $rv = $sth->execute( $file, $lang)  or croak $sth->errstr;
    } else {
	$sth = $dbh->prepare($SQLexist)   or croak $dbh->errstr;
	my $rv = $sth->execute( $file, $engine, $lang)  or croak $sth->errstr;
    }
    my $rows = $sth->rows;
    my $rc   = $sth->finish;

    $dbh->disconnect();
    return $rows;
}


# We Replace instead of Insert so the table index will keep
# one record per set of unique ocr parameters
my $SQLreplace = <<ENDSTAT2;
REPLACE INTO ocr 
( 
  imageFile,
  ocrEngine ,
  langParam,
  brightness,
  contrast,
  avgWordConfidence,
  numWords ,
  startOcr ,
  timeOcr ,
  remarks ,
  imageFileSize,
  outputText,
  outputHocr
)
VALUES
( 
?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME( ?), ?, ?, ?, ?, ?
);
ENDSTAT2

# insert or replace a tuple
sub insertOCR {
    my ( $input, $engine, $lang, $brightness, $contrast,
	 $avgwconf, $nwords, $starttime, $time, $remarks, $orig_size, $intxt, $gzhocr) =  @_;

    my $dbh = DBI->connect( "DBI:mysql:database=$dbname;host=$hostname", $username, $password,
			    {RaiseError => 0, PrintError => 0, mysql_enable_utf8 => 1}
	)
	or croak "Could not connect to database: $DBI::errstr" ;

    my $rows = $dbh->do( $SQLreplace, undef,
			$input, $engine, $lang, $brightness, $contrast,
			$avgwconf, $nwords, $starttime, $time, $remarks, $orig_size, $intxt, $gzhocr) ;
    $dbh->disconnect();
    return  "sub ocr results pre-existing $input.hocr rows $rows \n";
}


# Get the most recent compressed hocr for an image
my $SQLget = <<ENDSTAT3;
SELECT outputHocr
    FROM ocr 
    WHERE imageFile = ?
ORDER BY
    startOcr desc ;
ENDSTAT3

# get a tuple: the most recent ocr results for a specified image
sub getOCR {
    my ( $file ) =  @_;

    my $dbh = DBI->connect( "DBI:mysql:database=$dbname;host=$hostname", $username, $password,
			    {RaiseError => 0, PrintError => 0, mysql_enable_utf8 => 1}
	)
	or croak "Could not connect to database: $DBI::errstr" ;

    my $sth = $dbh->prepare($SQLget)   or croak $dbh->errstr;
    my $rv = $sth->execute( $file)  or croak $sth->errstr;
    my $rows = $sth->rows;

    my $row = $sth->fetchrow_hashref;
    $sth->finish;
    $dbh->disconnect();

    return @$row{'ocr','outputHocr'};
}

1;

__END__
