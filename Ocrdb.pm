# DB access for the ocr table
#   for insert, check record

package Ocrdb;

use strict;
use warnings;
use diagnostics;

use Config::IniFiles;
use DBI;

use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION); #  %EXPORT_TAGS
use Exporter;
$VERSION = 0.98;
@ISA = qw(Exporter);
@EXPORT = qw( existsOCR insertOCR);

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
#NOW()

my $cfg = Config::IniFiles->new( -file => "/etc/c7aocr/tessdb.ini" );
my $username = $cfg->val( 'DBconn', 'username' ) ;
my $password = $cfg->val( 'DBconn', 'password' ) ;
my $hostname = $cfg->val( 'DBconn', 'hostname' ) ;
my $dbname   = $cfg->val( 'DBconn', 'dbname' ) ;

open(LOGFILE, ">>/tmp/testtess.log")
    || die "LOG open failed: $!";
my $oldfh = select(LOGFILE); $| = 1; select($oldfh);

# check for the existence of a tuple
sub existsOCR {
    my ( $file, $engine, $lang) =  @_;
    my $dbh = DBI->connect( "DBI:mysql:database=mydb;host=$hostname", $username, $password )
	|| die "Could not connect to database: $DBI::errstr" ;
    my $sth = $dbh->prepare($SQLexist)   or die $dbh->errstr;
    my $rv = $sth->execute( $file, $engine, $lang)  or die $sth->errstr;
    my $rows = $sth->rows;
    my $rc   = $sth->finish;

    $dbh->disconnect();
    return $rows;
}

# insert or replace a tuple
sub insertOCR {
    my ( $input, $engine, $lang, $brightness, $contrast,
	 $avgwconf, $nwords, $starttime, $time, $remarks, $orig_size, $intxt, $gzhocr) =  @_;

    my $dbh = DBI->connect( "DBI:mysql:database=mydb;host=$hostname", $username, $password ) || die "Could not connect to database: $DBI::errstr" ;

    my $rows = $dbh->do( $SQLreplace, undef,
			$input, $engine, $lang, $brightness, $contrast,
			$avgwconf, $nwords, $starttime, $time, $remarks, $orig_size, $intxt, $gzhocr) ;
    $dbh->disconnect();
    return  "sub ocr results pre-existing $input.hocr rows $rows \n";
}

1;

__END__
