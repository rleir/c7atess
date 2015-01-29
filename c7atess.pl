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

# warn user (from perspective of caller)
use Carp;

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

# get just the text out of the .hocr file, and save it to the .txt file
sub saveUnformattedText {
    my ($outHcr, $outTxt) =  @_;
    # open the HOCR file and sniff the encoding, and apply it. 
    my $hocrfilehandle = html_file($outHcr); # , \%options);

    # This "shortcut" constructor implicitly calls $new->parse_file(...)
    my $tree = HTML::TreeBuilder->new_from_file(  $hocrfilehandle);

    # get just the text from the hocr
    my $formatter = HTML::FormatText->new( leftmargin => 0, rightmargin => 500);
    my $unformattedtext = $formatter->format($tree);

    my $utf8flag = utf8::is_utf8($unformattedtext);
    if( ! $utf8flag) {
	print $logFile "WARN unformattedtext == utf8 == false $outHcr \n";
    };
    # write the text file
    open ( TXTFILE, "> :encoding(UTF-8)", $outTxt) #actually check if it is UTF-8
	or croak "Cannot open $outTxt: $!";

    print TXTFILE $unformattedtext
	or croak "Cannot write to $outTxt: $!";

    close (TXTFILE )
	or croak "Cannot close $outTxt: $!";
    return $unformattedtext;
}

# count the words
sub countWords {
    my ( $unformattedtext) = @_;
    # get the text into an array
    my @dup_list = split(/ /, $unformattedtext);
    # sort uniq
    my @uniq_list = uniq(@dup_list);
    # count words
    my $nwords = scalar @uniq_list;
    # put all in a string
    #my $wordList = join(' ', @uniq_list);  # zzz not used
    return $nwords;
}

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


my $tessver = `tesseract --version 2>&1`;
$tessver =~ s/tesseract ([0-9]*.[0-9]*).*/$1/s;

# This is saved in the DB ocrEngine field
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
#$inbase =~ s|^/collections.new/pool[0-9]/aip/||

# take a valid TDR filepath, leaving the prefix whatevers
my $matchedIt = ( $inbase =~ s|^.*?/([a-z]+/[0-9]{3}/[a-z]+\.[a-z_0-9]+?/data/sip/data/files/[0-9]+\.[a-z]+?)$|$1|i );
if( !$matchedIt) {
    print $logFile "ERROR === bad dirpath $inbase = $dir . $base . $ext \n";
    exit 0;
}

# check the DB to see if the item has been processed already with the current engine.
#if( existsOCR ( $inBase,  $enginePreproDescrip, $lang)) {

# check the DB to see if the item has been processed already with any version of the engine.
if( existsOCR ( $inBase, undef, $lang)) {
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
    print $logFile "ERROR ===no hcr $outHcr\n";
    exit 0;
}

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
#gzip \$hocrhtml, \$gzhocr ;

# get just the text out of the .hocr file, and save it to the .txt file
my $unformattedtext = saveUnformattedText($outHcr, $outTxt);

# count the words
my $nwords = countWords( $unformattedtext);

# remove the brightened file, which uses lots of disk space
unlink  $ofilename;

# save the word confidence values
my ($avgwconf, $nwords2) = saveStats( $outHcr,  $outStats);

print $logFile "INFO nwords unique $nwords all $nwords2  $inBase \n";

# remove the hocr file, which uses a bit of disk space
unlink $outHcr;

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


