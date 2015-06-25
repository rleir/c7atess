#!/usr/bin/perl
#
# Given a image file (jpeg, jpeg2000, png and tif),
# run OCR on it, generating xml, text, stats, and concordance.

# Steps:
#  - check the DB, skip existing
#  - preprocess the image
#  - run Tesseract or Ocropus or..
#  - make word stats
#  - save to DB
#
# Temp files were saved to a local tree that mirrors the tdr (change this!)
#             The directory will be created if it does not already exist.
#
# Before doing OCR, process the input image with 'adaptive thresholding':
#    we need the image to appear like a photocopy so that Tesseract's binarization
#    will be effective, though the source image might have uneven lighting and minor noise.
#
# This program is intended to be run in parallel on several servers, one instance per core.

#use common::sense;
use strict;
use warnings;
use diagnostics;

# warn user (from perspective of caller)
use Carp;

use Getopt::Long;
use Cwd 'abs_path';
use File::Path qw( make_path );
use File::Basename;
use Cwd;
use OCR::Ocrdb qw( existsOCR insertOCR );
use OCR::hocrUtils qw( hocr2words doFilterHocr);
use POSIX qw(strftime);
use IO::Compress::Gzip qw(gzip $GzipError) ;
use Graphics::Magick;

use constant { TRUE => 1, FALSE => 0 };

my $logFile;

# get imageMagick to scale and or rotate the image
# given: the input source file name
#        the output file name (no extension)
#        the extension of the input file
#        the required brightening factor
# returns the output file name
#
# Note: GraphicsMagick is a replacement for ImageMagick,
# giving better performance and fewer feature changes with new versions
#
sub magicBrighten {
    my ($sourceFile, $interfilenameNoExt, $ext, $brightenFactor) =  @_;

    my $ofilename = "";
    # my $image = Image::Magick->new;
    my $image=Graphics::Magick->new;

    my $x = $image->read( $sourceFile);
    if ("$x") {	print $logFile "ERROR image read = $x   \n"; }

    # convert jpeg2000 images to jpeg
    if( $image->Get('magick') eq "JP2") {
	# Going for lossless conversion
	$image->Set(quality=>100,compression=>'none',magick=>'jpeg');
#	$image->Strip(); # 	strip an image of all profiles and comments. This works in ImageMagick but not in GM
	$image->Profile(); # 	strip an image of all profiles and comments. This is the GM way instead of Strip
	$ofilename = $interfilenameNoExt . '.jpg';
    } else {
	$ofilename = $interfilenameNoExt . $ext;
    }

    # my $tempfile =  $interfilenameNoExt . "temp.jpg";

    $image->Quantize(colorspace=>'gray');
    my $q = $image->Clone();
    $q->Blur( radius=>0.0, sigma=>30.0); # sigma defaults to 1.0
    $x = $q->Composite ( compose=>'Divide', image=>$image );
#    $x = $image->Composite ( compose=>'Divide_Src', image=>$q, composite=>'t' );
    if ("$x") {	print $logFile "ERROR image modu = $x   \n";   }

#    $x = $image->Mogrify( 'modulate', brightness=>$brightenFactor );
#    if ("$x") {	print $logFile "image brighten = $x   \n";    }

    $x = $q->Write( $ofilename);
    if ("$x") { print $logFile "ERROR image write = $x   \n"; }
 
    # works well on typewriter copy
    # ref http://www.imagemagick.org/Usage/compose/#divide
# this is the command line corresponding to the above perlmagick
#    `convert $ofilename -colorspace gray \\( +clone -blur 0x20 \\) -compose Divide_Src -composite $tempfile`;

#tess3.03-IMlat
#    `convert $ofilename -negate -lat 15x15+10% -negate $tempfile`;
#    `mv $tempfile $ofilename`;

    # The recommended way to destroy an object is with undef
    undef $q;
    undef $image;
    return $ofilename;
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



##############################################
# Mainline
#
my $input  = ".";
my $lang   = "eng";
my $brightFactor = "99"; # obsolete
my $ocropus; # future
my $verbose;
my $help;
my $keep = FALSE; # obsolete
my $result = GetOptions (
                    "input=s"   => \$input,     # string
                    "lang=s"    => \$lang,      # string
                    "bright=s"  => \$brightFactor,   # 
                    "ocropus"   => \$ocropus,   # flag
                    "help"      => \$help,      # flag
                    "keep"      => \$keep,      # flag
                    "verbose"   => \$verbose);  # flag
if( $help || $input eq "." ) {
    warn "Usage $0 [--input=indirpath] [--lang=fra] --verbose\n";
    warn "or    $0 --help\n";
    exit 0;
}
#print $logFile "WARN inupt $input \n";

my $tessver = `tesseract --version 2>&1`;
# the output is in the form of
#   tesseract 3.03
#    leptonica-1.71
#     libjpeg 8d : libpng 1.2.51 : libtiff 4.0.3 : zlib 1.2.8
#
# we want just the version ie 3.03:
$tessver =~ s/tesseract ([0-9]*.[0-9]*).*/$1/s;

# The following gets saved in the DB ocrEngine field
my $enginePreproDescrip = "tess${tessver}-IMdivide";

open($logFile, '>>', "/var/log/c7aocr/testtesspho.log")
    || croak "LOG open failed: $!";
my $oldfh = select($logFile); $| = 1; select($oldfh);

# example input path
# /collections/tdr/oocihm/444/oocihm.lac_reel_c8008/data/sip/data/files/1869.jpg

# remove trailing filename
my ($base, $dir, $ext) = fileparse( $input, qr/\.[^.]*/ );
#my  ($base, $dir, $ext) = fileparse( $input, qr{\.stas});
my $inBase = $dir . $base . $ext; 

if ($base eq "revisions") {
    print $logFile "WARN pruned dir $inBase \n";
    exit 0;
}

# remove the prefix directories
# previously we removed 
#substr( $inBase, 0, 40) =~ s|/collections/||g ;

# now we have it automatically remove all up to the oocihm or oop:
# take a valid TDR filepath, leaving the prefix whatevers
my $matchedIt = ( $inBase =~ s|^.*?/([a-z]+/[0-9]{3}/[a-z]+\.[a-z_0-9]+?/data/sip/data/files/[0-9._a-z]+?)$|$1|i );
if( !$matchedIt) {
    print $logFile "ERROR === bad dirpath $inBase = $dir . $base . $ext \n";
    exit 0;
}

# check the DB to see if the item has been processed already with any version of the engine.
if( existsOCR ( $inBase, undef, $lang)) {
    exit 0; 
}

my $oDir = getcwd() . $dir;
my $interfilenameNoExt  = $oDir . $base;
my $interfilename = $oDir . $base . $ext;
           
my $outHcr   = $interfilename . ".hocr";

# make output dir
make_path $oDir;

my $starttime = time();

# brighten the input image by nn%
# also, convert any jp2 files to jpg and return the name
my $ofilename = magicBrighten ( $input, $interfilenameNoExt, $ext, $brightFactor);

# OCR the brightened image, producing a .hocr file:
`tesseract $ofilename $interfilename -l $lang quiet hocr`;

# check that the .hocr file was made
if ( ! -e  $outHcr) {
    print $logFile "ERROR ===no hcr $outHcr\n";
    exit 0;
}

# remove the brightened file, which uses lots of disk space
unlink  $ofilename;

# get the hocr info from the file
my $inhocr = "";
#Unset $/, the Input Record Separator, to make <> give the whole file at once.
{
    local $/=undef;
    open my $hocrFile, '<', $outHcr
	or croak "Couldn't open $outHcr: $!";
    $inhocr = <$hocrFile>;
    close $hocrFile;
} 

$inhocr = doFilterHocr ( $inhocr);

# save the filtered hocr to a file for debugging
# open my $out_fh, '>', $outHcr . "filt.hocr";
# print {$out_fh} $inhocr;
# close  $out_fh;

# The hocr info is stored in a format that is not utf8 because
# that caused problems in the gzip compression below.
my $utf8flag1 = utf8::is_utf8($inhocr);
if( $utf8flag1) {
    # we do not expect to see this in the log
    print $logFile "WARN inhocr == utf8 == true \n";
}

# compress it 
my $gzhocr = "";
gzip \$inhocr, \$gzhocr ;

# get some stats and text from the .hocr file
my ($avgwconf, $nwords, $nwords2, $unformattedtext, $diagnostic) = hocr2words( $outHcr);
if ( $diagnostic) {
    print $logFile $diagnostic;
}

# remove the hocr file, which uses a bit of disk space
unlink $outHcr;

print $logFile "INFO nwords unique $nwords all $nwords2  $inBase \n";

# find the size of the input image
my ($device, $inode, $mode, $nlink, $uid, $gid, $rdev, $imgFileSize,
    $atime, $mtime, $ctime, $blksize, $blocks) =
    stat( $input);

# oops, this time should be UTC or maybe 'floating' timezone though it does not matter much.
my $time = time() - $starttime;
my $remarks = "";

# insert or replace in the DB
insertOCR ( $inBase, $enginePreproDescrip, $lang, $brightFactor, "100",
	    $avgwconf, $nwords,
	    $starttime,
	    $time, $remarks, $imgFileSize, $unformattedtext, $gzhocr) ;
exit 0;


