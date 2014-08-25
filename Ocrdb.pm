# DB access for the ocr table
# pm for insert, check record

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
@EXPORT = qw(insertOCR);

# We Replace instead of Insert so the table index will keep
# one record per set of unique ocr parameters
my $statement = <<ENDSTAT;
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
'?', ?, ?, ?, ?, ?, ?, FROM_UNIXTIME( ?), ?, ?, ?, ?, ?
);
ENDSTAT
#NOW()

my $cfg = Config::IniFiles->new( -file => "/etc/c7aocr/tessdb.ini" );
my $username = $cfg->val( 'DBconn', 'username' ) ;
my $password = $cfg->val( 'DBconn', 'password' ) ;
my $hostname = $cfg->val( 'DBconn', 'hostname' ) ;
my $dbname   = $cfg->val( 'DBconn', 'dbname' ) ;

sub insertOCR {
    my ( $input, $engine, $lang, $brightness, $contrast, $avgwconf, $nwords, $starttime, $time, $remarks, $orig_size, $intxt, $gzhocr) =  @_;

    #if( 
    #return "already in DB $input \n"

    my $dbh = DBI->connect( "DBI:mysql:database=mydb;host=$hostname", $username, $password ) || die "Could not connect to database: $DBI::errstr" ;

    my $rows = $dbh->do($statement, undef,
			$input, $engine, $lang, $brightness, $contrast,
			$avgwconf, $nwords, $starttime, $time, $remarks, $orig_size, $intxt, $gzhocr) ;
    $dbh->disconnect();
    return  "sub ocr results pre-existing $input.hocr rows $rows \n";
}

1;

__END__
