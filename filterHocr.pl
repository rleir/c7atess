#!/usr/bin/perl
#
# Given a hOCR document, remove all words that are blank or consist only of punctuation,
# and return a valid .hOCR.
#
# libXML read
# filter out word nodes
# filter out line nodes
# libXML write
# 
# http://www.canadiana.ca/schema/2012/xsd/txtmap/txtmap.xsd
#
use common::sense;
use XML::LibXML;
#use XML::LibXML::PrettyPrint;
#use diagnostics;
use CIHM::hocrUtils qw( doFilterHocr);

# do not use open qw/:std :utf8/;
# http://stackoverflow.com/questions/21096900/how-do-i-avoid-double-utf-8-encoding-in-xmllibxml
# https://metacpan.org/pod/XML%3a%3aLibXML%3a%3aDocument#toString
# unlike toString for other nodes, on document nodes this function returns the XML
# as a byte string in the original encoding of the document (see the actualEncoding() method)! 
# This means you can simply do
# print {$out_fh} $doc->toString;

use Getopt::Long;
use Data::Dumper;

#================= main =============
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

# zzzz test with  french to check utf8
$inhocr = doFilterHocr ( $inhocr);

#my $pp = XML::LibXML::PrettyPrint->new(indent_string => "  ");
#$pp->pretty_print($filteredhocr); # modified in-place
if( $outfile eq "") {
    print $inhocr ;
} else {
    open my $out_fh, '>', $outfile;
    print {$out_fh} $inhocr;
#    $filteredhocr->toFile($outfile, 1);
}
exit 1;

#------------------------
