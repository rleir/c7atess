#!/usr/bin/perl
#
# Given a image file specifier,
# get the hocr from the ocr DB
# 

# example imageFile DB field:
# tdr/oocihm/444/oocihm.lac_reel_c8008/data/sip/data/files/1869.jpg

use strict;
use warnings;
use diagnostics;
use Getopt::Long;
use CIHM::Ocrdb qw( existsOCR insertOCR getOCR);

use IO::Uncompress::Gunzip qw(gunzip $GunzipError) ;

use constant { TRUE => 1, FALSE => 0 };

##############################################
# Mainline
#
my $help;
my $input = ".";
my $outfile= "";
my $engine;
# my $engine = "tess3.03-IMdivide";
my $result = GetOptions (
                    "input=s"   => \$input,     # string
                    "outfile=s"   => \$outfile,   # string
                    "engine=s"  => \$engine,     # string
                    "help"      => \$help);  # flag
if( $help || $input eq "." ) {
    print "Usage $0 [--input=imageFile-DB-field] [--engine=ocrEngine-DB-field] \n";
    print "or    $0 --help\n";
    print "engine defaults to wildcard, and the most recent .hocr is returned \n";
    print "output: hocr.gz in current dir\n";
    print "or    $0 [--outfile=filename] \n";
    exit 0;
}

# check the DB to get the item
my $gzhocr = getOCR( $input, $engine);

if( ! $gzhocr) {
    die "item not found $input \n";
}

if( $outfile eq "") {
    open (OUTFILE, '>hocr.gz');
    print OUTFILE $gzhocr;
    close (OUTFILE);

} else {

    # uncompress it (this needs bytes, not utf-8)
    my $rawhocr ;
    my $status = gunzip \$gzhocr, \$rawhocr 
        or die "gunzip failed: $GunzipError\n";

#    open my $out, '>:encoding(UTF8)', $outfile;
    open (OUTFILE, '>', $outfile);
    print OUTFILE $rawhocr;
    close (OUTFILE);
}

exit 1;


