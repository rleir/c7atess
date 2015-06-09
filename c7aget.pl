#!/usr/bin/perl
#
# check the DB, skip existing


# Given a image file specifier,
# get the hocr from the ocr DB

# example input path
# tdr/oocihm/444/oocihm.lac_reel_c8008/data/sip/data/files/1869.jpg

use strict;
use warnings;
use diagnostics;
use Getopt::Long;
use CIHM::Ocrdb qw( existsOCR insertOCR getOCR);
use IO::Compress::Gzip qw(gzip $GzipError) ;

use constant { TRUE => 1, FALSE => 0 };
my $logFile;

##############################################
# Mainline
#
my $help;
my $input = ".";
my $result = GetOptions (
                    "input=s"   => \$input,     # string
                    "help"      => \$help);  # flag
if( $help || $input eq "." ) {
    warn "Usage $0 [--input=indirpath] \n";
    warn "or    $0 --help\n";
    exit 0;
}

open($logFile, '>>', "/tmp/testtesspho.log")
    || die "LOG open failed: $!";
my $oldfh = select($logFile); $| = 1; select($oldfh);

# check the DB to get the item
my $gzhocr = getOCR( $input);

if( !  $gzhocr) {
    die "item not found  $input \n";
}
open (OUTFILE, '>hocr.gz');
print OUTFILE $gzhocr;
close (OUTFILE);

exit 0;


