#!/usr/bin/perl
#
# Given a image file (jpeg, png and tif), and an output directory
# run OCR on it, generating xml, text, stats, and concordance.
# The directory will be created if it does not already exist.
# Before doing OCR, brighten the input image as necessary.
#

use strict;
use warnings;
use diagnostics;
use Getopt::Long;
use Cwd 'abs_path';
use HTML::FormatText;
use HTML::Parse;
use HTML::TagParser;
use File::Path qw( make_path );
use File::Basename;
use Cwd;
use Image::Magick ;                # brighten

use constant { TRUE => 1, FALSE => 0 };

# get imageMagick to scale and or rotate the image
sub magicBrighten {
    my ($sourceFile, $interfilename, $brightenFactor) =  @_;

    my $image = Image::Magick->new;
    my $x = $image->read( $sourceFile);
    if ("$x") {
	print LOGFILE "image read = $x   \n";
    }
    print LOGFILE "sourceFile: $sourceFile    \n";

    $x = $image->Mogrify( 'modulate', brightness=>$brightenFactor );
    if ("$x") {
	print LOGFILE "image brighten = $x   \n";
    }

    $x = $image->Write( $interfilename);
    if ("$x") {
	print LOGFILE "image write = $x   \n";
    }
}

# The .hocr contains these tags:
# <span 
# class='ocrx_word'
# id='word_1_331'
# title='bbox 1451 679 1457 686; x_wconf 76'
# lang='eng'
# dir='ltr'>
#  <em>I</em>
# </span>
sub saveStats {
    my ( $outHcr,  $outStats) = @_;
    open( STFILE, "> $outStats");

    # get just the x_wconf values from the hocr file:
    # write to a stats file with a wconf per line
    my $confsum = 0;
    my $confcount = 0;

    my $html = HTML::TagParser->new( $outHcr );
    my @list = $html->getElementsByTagName( "span" );
    foreach my $elem ( @list ) {
	my $innertext = $elem->innerText;

	my $titlevalue = $elem->getAttribute( "title" );
	my $wconf = "none";
	if ( $titlevalue =~ / x_wconf ([0-9]*)/ ) {
	    $wconf = $1;
	    $confsum += $1;
	    $confcount ++;
	}
	print STFILE " $wconf $innertext \n";
    }
    # avoid divide by zero
    if( $confcount == 0) { $confcount ++; }
    my $avg = $confsum / $confcount;

    print STFILE " $avg average \n";
    close( STFILE);
}

##############################################
# Mainline
#

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
my $interfilename = $oDir . $base;
           
print LOGFILE "sub op is $interfilename\n";
#print LOGFILE "sub ext is $ext\n";  blank!
my $outHcr   = $interfilename . ".hocr";
my $outTxt   = $interfilename . ".txt";
my $outStats = $interfilename . ".stas";

# make output dir
make_path $oDir;

# skip images that have been OCR'd already
if ( ! -e "$outHcr") {
    # brighten the input image by nn%
    magicBrighten ( $input, $interfilename, "150");

    # OCR to a hocr file:
    `tesseract $interfilename $interfilename -l $lang quiet hocr`;

    # get just the text from the hocr file:
    my $hocrhtml = parse_htmlfile( $outHcr);
    my $formatter = HTML::FormatText->new( leftmargin => 0, rightmargin => 500);
    my $ascii = $formatter->format( $hocrhtml);

    # write the text file
    open( TXTFILE, "> $outTxt");
    print TXTFILE $ascii;
    close( TXTFILE);
}
# save the word confidence values
saveStats( $outHcr,  $outStats);

exit 0;


