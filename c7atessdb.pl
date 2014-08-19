#!/usr/bin/perl
#
# Given a image file (jpeg, png and tif), and an output directory
# run OCR on it, generating xml and text and concordance
# The directory will be created if it does not already exist.
#
#

use strict;
use warnings;
use diagnostics;
use Getopt::Long;
use Cwd 'abs_path';
use HTML::FormatText;
use HTML::Parse;
use File::Path qw( make_path );
use File::Basename;
use Cwd;
use Config::IniFiles;

use constant { TRUE => 1, FALSE => 0 };

my $input  = ".";
my $lang   = "eng";
my $ocropus;
my $verbose;
my $help;
my $keep = FALSE;
my $result = GetOptions (
                    "input=s"   => \$input,     # string
                    "lang=s"    => \$lang,      # string
                    "ocropus"   => \$ocropus,   # flag
                    "help"      => \$help,      # flag
                    "keep"      => \$keep,      # flag
                    "verbose"   => \$verbose);  # flag
if( $help || $input eq "." ) {
    warn "Usage $0 [--input=indirpath] [--lang=fra] --verbose\n";
    warn "or    $0 --help\n";
    exit 0;
}

open(LOGFILE, ">>/tmp/testtess.log")
    || die "LOG open failed: $!";
my $oldfh = select(LOGFILE); $| = 1; select($oldfh);
print LOGFILE "Started:....\n";

#if( $verbose) {
    print LOGFILE "sub inp is $input\n";
#}

# example input path
# /collections/tdr/oocihm/444/oocihm.lac_reel_c8008/data/sip/data/files/1869.jpg

# prepend cwd, remove trailing filename
my ($base, $dir, $ext) = fileparse( $input );

my $oDir = getcwd() . $dir;
my $output = $oDir . $base;
#print LOGFILE "sub dir is $oDir\n";
print LOGFILE "sub op is $output\n";

# make output dir
make_path $oDir;

# skip images that have been OCR'd already
if ( -e "$output.hcr") {
    print LOGFILE "sub ocr results pre-existing $output.hcr \n";
    exit 0;
}

my $starttime = strftime "%Y-%m-%d %H:%M:%S", localtime;

# OCR to a hocr file:
`tesseract $input $output -l $lang quiet hocr`;

# the text appears in this tag:
#    <strong>well</strong>
my $outHcr = $output . ".hocr";
my $outTxt = $output . ".txt";

# get just the text from the hocr file:
my $html = parse_htmlfile( $outHcr);
my $formatter = HTML::FormatText->new( leftmargin => 0, rightmargin => 500);
my $ascii = $formatter->format( $html);

open( TXTFILE, "> $outTxt");
print TXTFILE $ascii;
close( TXTFILE);

# zzz now gz the hocr zzzzzzzzzzzzzzzzzzzzzz

my $statement = <<ENDSTAT;
INSERT INTO ocr 
( 
  `imageFile`,
  `avgWordConfidence`,
  `numWords` ,
  `startOcr` ,
  `timeOcr` ,
  `ocrEngine` ,
  `remarks` ,
  `imageFileSize`,
  `langParam`,
  `outputText`,
  `outputHocr`)
VALUES
( 
?, 1, 1, ?, ?, 'Tesseract', '', 1, ?, ?, ?
)
ENDSTAT
#NOW()

my $cfg = Config::IniFiles->new( -file => "/etc/c7aocr/tessdb.ini" );
my $username = $cfg->val( 'DBconn', 'username' ) ;
my $password = $cfg->val( 'DBconn', 'password' ) ;
my $hostname = $cfg->val( 'DBconn', 'hostname' ) ;
my $dbname   = $cfg->val( 'DBconn', 'dbname' ) ;

my $dbh = DBI->connect( "DBI:mysql:database=mydb;host=$hostname", $username, $password ) || die "Could not connect to database: $DBI::errstr" ;


#my $sth = $dbh->prepare($statement);
#my  $rc = $sth->bind_param($p_num, $bind_value);
#  $rv = $sth->execute;
#  @row_ary  = $sth->fetchrow_array;
#        $sth->finish;

my $rows = $dbh->do($statement,  $input, $starttime, time, $lang, $ascii, $html);
if( $rows != 1) {
    print LOGFILE "sub ocr results pre-existing $output.hcr \n";
}

$dbh->disconnect();
exit 0;


