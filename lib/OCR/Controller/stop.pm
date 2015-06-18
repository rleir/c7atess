package OCR::Controller::stop;
use Moose;
use namespace::autoclean;

use Scalar::Util qw(looks_like_number);

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

OCR::Controller::stop - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    my $jobpid = "NAJ";
    my $filename = '/var/run/c7aocr/jobpids';
    if (open(my $fh, '<:encoding(UTF-8)', $filename)) {
        if ( ! defined($fh) ) {
            warn "YikesCould not open file '$filename' $!";
        } elsif ( my $row = <$fh>) {
            chomp $row;
            $jobpid = $row;
        }
    } else {
        warn "Could not open file '$filename' $!";
    }

    # exit if "none" or "NAJ" or ""
    # jobpid should be a number
    if( !looks_like_number($jobpid )) {
        $c->response->body("not number1 $jobpid  ");
        return;
    }
    # I do not like to issue the 'kill' command without being sure, so we double-check the PID.
    # First, work from parent to grandchild.
    # Second, work from grandchild to parent.
    # If there is agreement on the PID for gnu parallel, then send it a TERM to shut all down gently.

    # find the bin/sh which is the child of our c7aocr job?
    my $child  = childProc("sh\ -c\ find", $jobpid);
    if( !looks_like_number($child )) {
        $c->response->body("not number2 $child  ");
        return;
    }
    my $parPID = childProc("perl\ /usr/bin/parallel", $child);

    # Second, which process named 'parallel' is the child of the child of our c7aocr job?
    # The answer should be unique.
    # Find parent pids of parallel processes:
    my $procs_ref = parentPID( "bin/parallel");
    my @procs = @$procs_ref;
    
    $c->log->debug( "procs @procs $jobpid ") if( $c->log->is_debug);

    foreach ( @procs ) {
        my $pid = $_;


        $c->log->debug( "p==rocs $pid  ") if( $c->log->is_debug);
        if( $jobpid eq $pid) {
            $c->log->debug( "p==found $pid ") if( $c->log->is_debug);
            last;
        }
    }
# if First and Second agreee zzz
            # finish current tasks then stop everything
            # by sending TERM to the parallel
            `kill -TERM $parPID`;


    my $deb = `ps -aef |grep $jobpid `;
    $c->response->body("killed $jobpid ==ps== $deb ");
}

# find the bin/sh which is the child of our c7aocr job?
sub childProc {
    my ( $cmd, $jobpid) = @_;

    my $re = "|^$cmd|";
    my $procs = `ps a -o pid,ppid,cmd |grep $jobpid`;
#    $c->log->debug( "procs $procs ") if( $c->log->is_debug);
    my $childPID = "none";
    while ($procs =~ /^(\d*?) (\d*?) (.+?)/sg) {
        my $pid = $1;
        my $ppid = $2;
        my $cmd = $3;
        if( $cmd =~ $re) {
            $childPID = $pid;
#            $c->log->debug( "found $1 $2 $3 ") if( $c->log->is_debug);
            last;
        }
    }
    return $childPID;
}


sub parentPID :Local {
    my ( $cmd ) = @_;

    my $procs = `ps a -o pid,ppid,cmd |grep $cmd `;

#    $c->log->debug( "procs $procs ") if( $c->log->is_debug);
    my @ppids;
    while ($procs =~ /^(\d*?) (\d*?) /sg) {
        my $pid = $1;
        my $ppid = $2;
#        $c->log->debug( "p==rocs $pid $ppid ") if( $c->log->is_debug);
        push @ppids, $ppid;
    }
    return \@ppids;
}

=encoding utf8

=head1 AUTHOR

Rick Leir

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
