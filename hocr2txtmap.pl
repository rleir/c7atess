#!/usr/bin/perl
#
# Given a hocr document, take the bboxes and 
# create the equivalent txtmap document
#
# Input and output can be files or piped STDIN and STDOUT
# 
# http://www.canadiana.ca/schema/2012/xsd/txtmap/txtmap.xsd
#
use common::sense;
use OCR::hocrUtils qw( hocr2txtmap);

use diagnostics;

use Getopt::Long;
use Data::Dumper;

my $outfile= "";
my $verbose;
my $help;
my $result = GetOptions (
                    "outfile=s" => \$outfile,   # string
                    "help"      => \$help,      # flag
                    "verbose"   => \$verbose);  # flag

if( $help ) {
    print "Usage $0 ifilename > ofilename\n";
    print "or    $0 < ifilename > ofilename \n";
    print "or    $0 [--outfile=filename] --verbose\n";
    print "or    $0 --help\n";
    exit 0;
}

my $inhocr;
# Unset $/, the Input Record Separator, to make <> give the whole file at once.
{
    local $/=undef;
    $inhocr = <>;
} 

my $txtmap = hocr2txtmap ( $inhocr);

if( $outfile == "") {
    print $txtmap->toString;
} else {
    $txtmap->toFile($outfile, 1);
}
exit 1;

#------------------------

