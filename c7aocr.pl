#!/usr/bin/perl
#
# Given a directory containing images (jpeg, png and tif), and an output directory
# run OCR on all, generating xml and text and concordance

# no no  gen a pdf with a text layer to support searching.
# 
# Automatically uses all cores of the server in parallel.
#
# Note: currently the input path needs to be absolute IE /coll/tdr/oo.. or the prune clause will be ineffective.

# Optionally use Tesseract 
#   (product quality)          (bounding box to the word level)
# or Ocropus 
#   (research project quality) (bounding box to the line level) (handles columns correctly).
#
#

use strict;
use warnings;
use diagnostics;

#use File::Temp qw(tempdir);
use Getopt::Long;
use Cwd 'abs_path';

use constant { TRUE => 1, FALSE => 0 };

my $input  = ".";
my $lang   = "eng";
my $ocropus;
my $verbose;
my $help;
#my $keep = FALSE;
my $result = GetOptions (
                    "input=s"   => \$input,     # string
                    "lang=s"    => \$lang,      # string
                    "ocropus"   => \$ocropus,   # flag
                    "help"      => \$help,      # flag
#                    "keep"      => \$keep,      # flag
                    "verbose"   => \$verbose);  # flag
if( $help || $input eq "." ) {
    print "Usage $0 [--input=indirpath] [--lang=fra] --verbose\n";
    print "or    $0 --help\n";
    exit 0;
}

if( $verbose) {
    print "input is $input\n";
}
my $data = abs_path($input);

if( $verbose) {
    print "inp is $data\n";
}

# input files include all .jpg, .jp2, and .tif in the tree specified.
my $fileTypes  = " -name \\*.jpg -o -name \\*.jp2 -o -name \\*.tif ";

# jobs are distributed to the 'eight' server and are also run on the local machine.
# an arbitrary (yikes) delay saves ssh from being 'overwhelmed'.
my $serverList = " -S richard\\\@eight -S : --sshdelay 0.2 ";

# The slave job OCR's an image, and stores the results.
my $slaveJob   = " ./c7atess.pl --input={} --lang=$lang --verbose ";

# avoid doing the revision directories, just the sip dirs.
my $prune      = " -path /\\*/revisions -prune -o ";

# only tesseract for now
if( ! $ocropus) {

    # do slave jobs in parallel 
    print "find $data $prune $fileTypes | parallel $serverList $slaveJob \n";
    `find $data $prune $fileTypes | parallel $serverList $slaveJob `;

    # gen pdf's in parallel
#    `find . -type f -name \\*.ppm | parallel hocr2pdf -i {} -o {.}-new.pdf "<" {.}.hocr` ;
#    if( $? >> 8) { die "cannot find and h2p $? \n" };

}

exit 0;

