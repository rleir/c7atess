#!/usr/bin/perl
#
# temporary: load the DB from the files on arundel

# Given a image file (jpeg, png and tif), and an output directory
# run OCR on it, generating xml and text and concordance
# The directory will be created if it does not already exist.
#
#

use common::sense;
#use diagnostics;

use Getopt::Long;
use Cwd 'abs_path';
use HTML::FormatText;
use HTML::Parse;
use File::Path qw( make_path );
use File::Basename;
use Cwd;
use CIHM::Ocrdb qw( insertOCR );
#use POSIX qw(strftime);
use IO::Compress::Gzip qw(gzip $GzipError) ;
use List::MoreUtils qw(uniq);

use constant { TRUE => 1, FALSE => 0 };

my $input  = ".";
my $lang   = "eng";
my $ocropus;
my $help;
my $keep = FALSE;
my $result = GetOptions (
                    "input=s"   => \$input,     # string
                    "lang=s"    => \$lang,      # string
                    "ocropus"   => \$ocropus,   # flag
                    "help"      => \$help,      # flag
                    "keep"      => \$keep);  # flag
if( $help || $input eq "." ) {
    warn "Usage $0 [--input=indirpath] [--lang=fra] \n";
    warn "or    $0 --help\n";
    exit 0;
}

open(LOGFILE, ">>/tmp/testdbtess.log")
    || die "LOG open failed: $!";
my $oldfh = select(LOGFILE); $| = 1; select($oldfh);
print LOGFILE "sub inp is $input\n";

# example input path
# /home/rleir/ocr/pdfocr/collections/tdr/oocihm/444/oocihm.lac_reel_c8008/data/sip/data/files/1869.jpg.hocr

# prepend cwd, remove trailing filename
#my ($base, $dir, $ext) = fileparse( $input, qr/\.[^.]*/ );
my  ($base, $dir, $ext) = fileparse( $input, qr{\.stas});

# this gives us the image created in the brightening operation
my $inBase = $dir . $base; 

my $inHcrFile   = $inBase . ".hocr";
my $inTxtFile   = $inBase . ".txt";
my $inStatsFile = $inBase . ".stas";

my $inBrightenedImage = $inBase;
# if the original was jp2 then the brightened is jpg
substr( $inBrightenedImage, -4, 4) =~ s/.jp2/.jpg/g;

# remove the prefix directories
substr( $inBase, 0, 40) =~ s|/home/rleir/ocr/pdfocr/collections/||g ;

print LOGFILE "sub input is $inHcrFile \n";

my $brightFactor = "";
my $last = "0";
if( -e $inStatsFile) {
    # get the statistics info from the file
    # get avg word confidence from last line of the file
    open( STSFILE, "$inStatsFile");
    while (<STSFILE>) { 
	$last = $_;
    }
    close( STSFILE);

    $brightFactor = "150";
} else {
    $brightFactor = "101";
}
my $avgwconf = substr $last, 1, 2;

# get the txt info from the file
my $intxt = "";
#Unset $/, the Input Record Separator, to make <> give the whole file at once.
{
    local $/=undef;
    open FILE, $inTxtFile or die "Couldn't open file: $!";
    $intxt = <FILE>;
    close FILE;
} 

# get the text into an array
my @dup_list = split(/ /, $intxt);
# sort uniq
my @uniq_list = uniq(@dup_list);
# count words
my $nwords = scalar @uniq_list;
# put all in a string
my $wordList = join(' ', @uniq_list);

# get the hocr info from the file
my $inhocr = "";
#Unset $/, the Input Record Separator, to make <> give the whole file at once.
{
    local $/=undef;
    open FILE, $inHcrFile or die "Couldn't open file: $!";
    $inhocr = <FILE>;
    close FILE;
} 
my $gzhocr = "";
gzip \$inhocr, \$gzhocr ;

# optimize by removing the /collections/tdr prefix
# problems with varchar join speed
# use surrogate key (hash the varchar)

my $remarks = "";

# image file size for use in analytics, ie 'how many words per image size unit'
#           or 'how large is average image in this series'
#           or 'does conf correlate with size'
#           or 'how long does ocr take for size of n'
# for now, we use the size of the brightened image zzzz
my $imgFileSize = 0;

# brightening
# contrast
my $time = 0;
my $brightened_time = 0;
if( -e $inBrightenedImage ) {

    # get modified time for the files
    my ($orig_device, $orig_inode, $orig_mode, $orig_nlink, $orig_uid, $orig_gid, $orig_rdev, $orig_size,
	$orig_atime, $orig_mtime, $orig_ctime, $orig_blksize, $orig_blocks) =
	    stat ( $inBrightenedImage );
    my ($device, $inode, $mode, $nlink, $uid, $gid, $rdev, $size,
	$atime, $mtime, $ctime, $blksize, $blocks) =
	    stat( $inTxtFile);
    # 9 mtime    last modify time in seconds since the epoch
    print LOGFILE "sub time is $orig_mtime inbase is  $inBrightenedImage $inBase\n";
    $brightened_time = $orig_mtime;
    # the time taken OCR'ing an image:
    $time = $mtime - $orig_mtime;
}

#temporary
my ($device, $inode, $mode, $nlink, $uid, $gid, $rdev, $size,
    $atime, $mtime, $ctime, $blksize, $blocks) =
    stat( $inTxtFile);

#use when doing the ocr right now
#my $starttime = strftime "%Y-%m-%d %H:%M:%S", localtime;

# get the time from the brightened image file
#my $starttime = strftime "%Y-%m-%d %H:%M:%S",  $orig_mtime;


insertOCR ( $inBase, "tess3.03", $lang, $brightFactor, "100",
	    $avgwconf, $nwords,
	    $mtime,  #	    $brightened_time,
	    $time, $remarks, $imgFileSize, $wordList, $gzhocr) ;

exit 0;


