#!/usr/bin/perl
#
# Given a directory containing images (jpeg, png and tif),
# run OCR on all, generating xml and text and concordance.
# The results are put in the ocr database.
# Automatically uses all cores of the servers in parallel.
# The input directory can actually be anything that find(1) accepts, perhaps with wildcards, such as 
#     ./DoJob.pl --input=/collections/tdr/oocihm/8* 
# Note: currently the input path needs to be absolute IE /coll/tdr/oo.. or the prune clause will be ineffective.

# Option input: select an image 
# Option lang: instructs Tesseract to use the specified language dictionary
# Option engine: choose Tesseract or Ocropus or ..
# Option help: echo usage info
# Option keep: do not delete intermediate files after the info has been put in the DB
# Option verbose: just echos the input location
# Option start, stop the scheduler 
#

# Optionally use Tesseract 
#   (product quality)          (bounding box to the word level)
# or Ocropus (future)
#   (research project quality) (bounding box to the line level) (handles columns correctly).
#
#
# now q a job, process and del zzzzzzzz

# Turn on "autoflush" so the console output can be written to same line:
$| = 1;

use common::sense;

use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP qw();
use Try::Tiny;

use Getopt::Long;
use OCR::Ocrdb qw( pushOCRjob getOCRjob doneOCRjob );
use Cwd 'abs_path';
use File::Touch;
use Fcntl qw/ :flock /;
#  sub LOCK_EX { 2 } ## exclusive lock
#  sub LOCK_UN { 8 } ## unlock

use File::Basename;

use constant { TRUE => 1, FALSE => 0 };

# use the operating system’s facility for cooperative locking: 
# at startup, attempt to lock a certain file. If successful, 
# this program knows it’s the only one. Otherwise, another process
# already has the lock, so the new process exits. 
my $base0 = basename $0;

my $LOCK = "/var/run/ocr/.lock-$base0";

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

my $endfilename = "/var/run/ocr/endScheduler";

my $input    = ".";
my $notify   = 'richard@c7a.ca';
my $lang     = "eng";
my $priority = 5;  
my $ocropus;
my $verbose;
my $help;
my $stopScheduler   = FALSE;
my $startScheduler = FALSE;
my $result = GetOptions (
                    "input=s"   => \$input,     # string
                    "notify=s"  => \$notify,    # string
                    "lang=s"    => \$lang,      # string
                    "priority"  => \$priority,  # flag
                    "ocropus"   => \$ocropus,   # flag
                    "help"      => \$help,      # flag
                    "stopScheduler"   => \$stopScheduler,      # flag
                    "startScheduler" => \$startScheduler,    # flag
                    "verbose"   => \$verbose);  # flag
if( $help || 
    (( $stopScheduler == FALSE) && ( $startScheduler == FALSE) && ( $input eq "." ))) {
    print "Usage $0 [--input=indirpath] [--lang=eng (default)] \n";
    print '         [--notify=sam@some.org] \n';
    print "         [--priority=5 (default, 1 is max)] --verbose\n";
    print "or    $0 --help\n";
    print "or    $0 --stopScheduler\n";
    print "or    $0 --startScheduler\n";
    exit 0;
}

if( $verbose) {
    print "input is $input\n";
}

my $email_from = 'richard@c7a.ca';

# input files include all .jpg, .jp2, and .tif in the tree specified.
my $fileTypes  = " -name \\*.jpg -o -name \\*.jp2 -o -name \\*.tif ";

# jobs are distributed to the 'eight' server and are also run on the local machine.
# an arbitrary (yikes) delay saves ssh from being 'overwhelmed'.
my $serverList = " -S richard\\\@darcy-pc -S richard\\\@yb -S richard\\\@xynotyro -S richard\\\@aragon -S richard\\\@zamorano -S : --sshdelay 0.2 ";

# The slave job OCR's an image, and stores the results.
my $slaveJob   = " ./DoImage.pl --input={} --lang=$lang --verbose ";

# avoid doing the revision directories, just the sip dirs.
my $prune      = " -path /\\*/revisions -prune -o ";

if( $stopScheduler) {
    print "Scheduler stopping when current job completes \n";
    my @file_list = ( $endfilename);
    my $count = touch(@file_list);

} elsif ( $startScheduler) {
    my $token = take_lock;

    unlink $endfilename;
    print "Scheduler starting, --stopScheduler to stop it \n";

    my $loop = 0;
    while( ! -e $endfilename) {
        # get an item from DB
        $loop++;

        my( undef, $idjobQueue, $command, $parm1, $parm2, $notify) = getOCRjob();

        if( !defined ($command)) {
            print "sleeping $loop \r";
            sleep( 1);

            # next;
        } else {
            my $data = abs_path($parm1);

            # only tesseract for now
            # if( ! $ocropus) {

            # do slave jobs in parallel 
            print "dummy find $data $prune $fileTypes | parallel $serverList $command \n";
 #           `find $data $prune $fileTypes | parallel $serverList $command `;
            
            doneOCRjob( $idjobQueue); # in the db, mark it finished (just delete it);

            my $email_body = "OCR $command of $parm1 finished";

            # produce an Email::Abstract compatible message object,
            # my $message = Email::MIME->create( ... );
            my $message = Email::Simple->create(
                header => [
                    From    =>  $email_from,
                    To      => $notify,
                    Subject => 'OCR Job finished',
                ],
                body => $email_body,
                );

            try {
                sendmail(
                    $message,
                    {
                        from => $email_from,
                        transport => Email::Sender::Transport::SMTP->new({
                            host => 'smtp.cihm',
                            port => 25,
                                                                         })
                    }
                    );
            } catch {
                warn "sending failed: $_";
            };
        }
    }
    unlock ($token);
    print "Scheduler stopped, current job completed \n";
    exit 0;

} else {

    if ( $input eq "." ) {
        die "no input";
    }
    my $data = abs_path($input);

    if( ! $data) {
        die "inp $input is null";
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
    my $collID = "dummysipspec";
    my $starttime = time();

    # normally, jobs are pushed from the Dashboard Controller.
    # Here, we are starting jobs from the CLI
    my $ret = pushOCRjob( "CLI", 
                          $priority, 
                          $notify,
                          $data, 
                          " ./DoImage.pl --input={} --lang=eng --verbose ", 
                          $starttime,
                          $collID );
}

exit 1;

