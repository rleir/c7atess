#!/usr/bin/perl
#
# driven by find from the tdr
# check the DB, skip existing
# brighten
# ocr
# stats
# to DB

# Given a image file (jpeg, jpeg2000, png and tif),
# run OCR on it, generating xml, text, stats, and concordance.
#
# The output directory is in a local tree that mirrors the tdr.
# The directory will be created if it does not already exist.
# Before doing OCR, brighten the input image as necessary.
#
# This program is run in parallel on several servers, one instance per core.

use strict;
use warnings;
use diagnostics;
use Getopt::Long;
use Cwd 'abs_path';
use HTML::FormatText;
use HTML::TreeBuilder;
use HTML::TagParser;
use File::Path qw( make_path );
use File::Basename;
use Cwd;
use Ocrdb qw( existsOCR insertOCR );
use POSIX qw(strftime);
use IO::Compress::Gzip qw(gzip $GzipError) ;
use IO::HTML qw(html_file);
use List::MoreUtils qw(uniq);
#use Image::Magick ;                # brighten
use Graphics::Magick;

use constant { TRUE => 1, FALSE => 0 };

# get imageMagick to scale and or rotate the image
# given: the input source file name
#        the output file name (no extension)
#        the extension of the input file
#        the required brightening factor
# returns the output file name
sub magicBrighten {
    my ($sourceFile, $interfilenameNoExt, $ext, $brightenFactor) =  @_;

    my $ofilename = "";
    # my $image = Image::Magick->new;
    my $image=Graphics::Magick->new;

    my $x = $image->read( $sourceFile);
    if ("$x") {	print LOGFILE "ERROR image read = $x   \n"; }

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
    print LOGFILE "INFO outpppFile: $ofilename    \n";

    # my $tempfile =  $interfilenameNoExt . "temp.jpg";

    $image->Quantize(colorspace=>'gray');
    my $q = $image->Clone();
    $q->Blur( radius=>0.0, sigma=>30.0); # sigma defaults to 1.0
    $x = $q->Composite ( compose=>'Divide', image=>$image );
#    $x = $image->Composite ( compose=>'Divide_Src', image=>$q, composite=>'t' );
    if ("$x") {	print LOGFILE "ERROR image modu = $x   \n";   }

#    $x = $image->Mogrify( 'modulate', brightness=>$brightenFactor );
#    if ("$x") {	print LOGFILE "image brighten = $x   \n";    }

    $x = $q->Write( $ofilename);
    if ("$x") { print LOGFILE "ERROR image write = $x   \n"; }
 
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

# save stats to a file
# each line contains the word confidence followed by the word
# the last line contains the average word confidence (weighted by word frequency)
# the return is the average and the number of words
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
    return ($avg, $confcount) ;
}

##############################################
# Mainline
#
my $input  = ".";
my $lang   = "eng";
my $brightFactor = "99";
my $ocropus;
my $verbose;
my $help;
my $keep = FALSE;
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

# This is saved in the DB ocrEngine field
my $enginePreproDescrip = "tess3.03-IMdivide";

open(LOGFILE, ">>/tmp/testtesspho.log")
    || die "LOG open failed: $!";
my $oldfh = select(LOGFILE); $| = 1; select($oldfh);

# example input path
# /collections/tdr/oocihm/444/oocihm.lac_reel_c8008/data/sip/data/files/1869.jpg

# remove trailing filename
my ($base, $dir, $ext) = fileparse( $input, qr/\.[^.]*/ );
#my  ($base, $dir, $ext) = fileparse( $input, qr{\.stas});
my $inBase = $dir . $base . $ext; 

if ($base eq "revisions") {
    print LOGFILE "WARN pruned dir $inBase \n";
    exit 0;
}

# remove the prefix directories
substr( $inBase, 0, 40) =~ s|/collections/||g ;
print LOGFILE "INFO sub inp is  $inBase \n";
# check the DB to see if the item has been processed already with the current engine.
if( existsOCR ( $inBase,  $enginePreproDescrip, $lang)) {
    exit 0; 
}

my $oDir = getcwd() . $dir;
my $interfilenameNoExt  = $oDir . $base;
my $interfilename = $oDir . $base . $ext;
           
my $outHcr   = $interfilename . ".hocr";
my $outTxt   = $interfilename . ".txt";
my $outStats = $interfilename . ".stas";

# make output dir
make_path $oDir;

my $starttime = time();

# brighten the input image by nn%
# also, convert any jp2 files to jpg and return the name
my $ofilename = magicBrighten ( $input, $interfilenameNoExt, $ext, $brightFactor);

# OCR the brightened image, producing a hocr file:
`tesseract $ofilename $interfilename -l $lang quiet hocr`;

if ( ! -e  $outHcr) {
    print LOGFILE "ERROR ===no hcr $outHcr\n";
    exit 0;
}

# get the hocr info from the file
my $inhocr = "";
#Unset $/, the Input Record Separator, to make <> give the whole file at once.
{
    local $/=undef;
    open FILE, $outHcr or die "Couldn't open file: $!";
    $inhocr = <FILE>;
    close FILE;
} 
# compress it
my $gzhocr = "";
gzip \$inhocr, \$gzhocr ;
#gzip \$hocrhtml, \$gzhocr ;

# open the HOCR file and sniff the encoding, and apply it. 
my $hocrfilehandle = html_file($outHcr); # , \%options);

# This "shortcut" constructor implicitly calls $new->parse_file(...)
my $tree = HTML::TreeBuilder->new_from_file(  $hocrfilehandle);

# get just the text from the hocr
my $formatter = HTML::FormatText->new( leftmargin => 0, rightmargin => 500);
my $unformattedtext = $formatter->format($tree);

# write the text file
open( TXTFILE, "> $outTxt");
binmode( TXTFILE, ":encoding(utf8)"); #actually check if it is UTF-8
print TXTFILE $unformattedtext;
close( TXTFILE);

# get the text into an array
my @dup_list = split(/ /, $unformattedtext);
# sort uniq
my @uniq_list = uniq(@dup_list);
# count words
my $nwords = scalar @uniq_list;
# put all in a string
my $wordList = join(' ', @uniq_list);  # zzz not used

# remove the brightened file, which uses lots of disk space
unlink  $ofilename;

# save the word confidence values
my ($avgwconf, $nwords2) = saveStats( $outHcr,  $outStats);

if( $nwords != $nwords2) {
    print LOGFILE "INFO unique nwords $nwords  $nwords2\n";
}

# find the size of the input image
my ($device, $inode, $mode, $nlink, $uid, $gid, $rdev, $imgFileSize,
    $atime, $mtime, $ctime, $blksize, $blocks) =
    stat( $input);

my $time = time() - $starttime;
my $remarks = "";

# insert or replace in the DB
insertOCR ( $inBase, $enginePreproDescrip, $lang, $brightFactor, "100",
	    $avgwconf, $nwords,
	    $starttime,
	    $time, $remarks, $imgFileSize, $unformattedtext, $gzhocr) ;
exit 0;


