#!/usr/bin/perl
#
# Given a directory containing images (jpeg, png and tif),
# run OCR on all, generating xml and text and concordance.
# The results are put in the ocr database.
# Automatically uses all cores of the servers in parallel.
# The input directory can actually be anything that find(1) accepts, perhaps with wildcards, such as 
#     ./c7aocr.pl --input=/collections/tdr/oocihm/8* 
# Note: currently the input path needs to be absolute IE /coll/tdr/oo.. or the prune clause will be ineffective.

# Option lang: instructs Tesseract to use the specified language dictionary
# Option engine: choose Tesseract or Ocropus or ..
# Option help: echo usage info
# Option keep: do not delete intermediate files after the info has been put in the DB
# Option verbose: just echos the input location
# 
#

# Optionally use Tesseract 
#   (product quality)          (bounding box to the word level)
# or Ocropus (future)
#   (research project quality) (bounding box to the line level) (handles columns correctly).
#
#

use common::sense;
#use strict;
#use warnings;
#use diagnostics;

#use File::Temp qw(tempdir);
use Getopt::Long;
use Cwd 'abs_path';

use constant { TRUE => 1, FALSE => 0 };

use Fcntl qw/ :flock /;
#  sub LOCK_EX { 2 } ## exclusive lock
#  sub LOCK_UN { 8 } ## unlock

use File::Basename;

# use the operating system’s facility for cooperative locking: 
# at startup, attempt to lock a certain file. If successful, 
# this program knows it’s the only one. Otherwise, another process
# already has the lock, so the new process exits. 

my $base0 = basename $0;

my $LOCK = "/var/run/c7aocr/.lock-$base0";

sub take_lock {
    open my $fh, ">", $LOCK or die "$base0: open $LOCK: $!";

    unless (flock $fh, LOCK_EX | LOCK_NB) {
        warn "failed to lock $LOCK; exiting.";
        exit 1;
    }
    $fh;
}

sub unlock {
    my ($fh) = @_;
    flock($fh, LOCK_UN) or die "Cannot unlock - $!\n";
}

my $token = take_lock;

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

if( ! $data) {
    print "inp is null \n";
    unlock ($token);
    exit 0;
}

if( $verbose) {
    print "inp is $data\n";
}

if ($lang =~ /(\w{1}[-\w]*)/ ) {
    $lang = "$1";
} else {
    warn ("TAINTED DATA : $lang: $!");
    $lang = ""; # successful match did not occur
}

# input files include all .jpg, .jp2, and .tif in the tree specified.
my $fileTypes  = " -name \\*.jpg -o -name \\*.jp2 -o -name \\*.tif ";

# jobs are distributed to the 'eight' server and are also run on the local machine.
# an arbitrary (yikes) delay saves ssh from being 'overwhelmed'.
my $serverList = " -S richard\\\@darcy-pc -S richard\\\@yb -S richard\\\@xynotyro -S richard\\\@aragon -S richard\\\@zamorano -S : --sshdelay 0.2 ";

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

# rm /var/run/c7aocr/.lock-c7aocrtest.pl
# unlink $LOCK or warn "Could not unlink $LOCK: $!";
unlock ($token);

exit 1;

