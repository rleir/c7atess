#!/usr/bin/perl
#
# Given a hocr document, take the bboxes and 
# produce an html with a word position layer.
#
# Input and output can be files or piped STDIN and STDOUT
# 
# Input can be from the DB, given an imageFile name
#
use common::sense;
use CIHM::hocrUtils qw( hocr2html );
use CIHM::Ocrdb qw( getOCR );

#use IO::Compress::Gzip qw(gzip $GzipError) ;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError) ;

# utf-8 conversion
use Encode qw(decode encode);

use diagnostics;

use Getopt::Long;
use Data::Dumper;

my $imageFile= "";
my $outfile= "";
my $prefix= "\/";
my $verbose;
my $help;
my $result = GetOptions (
                    "imageFile=s" => \$imageFile, # string
                    "outfile=s"   => \$outfile,   # string
                    "prefix=s"    => \$prefix,    # string
                    "help"        => \$help,      # flag
                    "verbose"     => \$verbose);  # flag

if( $help ) {
    print "Usage $0 ifilename > ofilename\n";
    print "or    $0 < ifilename > ofilename \n";
    print "or    $0 [--imageFile=DBimageSpec] \n";
    print "or    $0 [--outfile=filename] --verbose\n";
    print "or    $0 [--prefix=path] \n";
    print "or    $0 --help\n";
    exit 0;
}

my $inhocr;
if( $imageFile eq "") {

    # Unset $/, the Input Record Separator, to make <> give the whole file at once.
    {
        local $/=undef;
        $inhocr = <>;
    }
} else {
    # my $engine = "tess3.03-IMdivide";
    my $engine; # we want whatever engine, newest startTime
    my $gzhocr = getOCR( $imageFile, $engine);

    # uncompress it (this needs bytes, not utf-8)
    my $rawhocr ;
    my $status = gunzip \$gzhocr, \$rawhocr 
        or die "gunzip failed: $GunzipError\n";
    $inhocr = $rawhocr ;
#    $inhocr = decode( 'UTF8', $rawhocr );
#    $inhocr = encode( 'UTF8', $rawhocr );
}

my $layerhtml = hocr2html ( $inhocr, $prefix);

if( $outfile eq "") {
    print $layerhtml ;
} else {
    open my $out, '>:encoding(UTF8)', $outfile;
    print {$out} $layerhtml;
    close $out;
}
exit 1;

#------------------------

