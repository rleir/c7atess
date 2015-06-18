package OCR::Controller::status;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

OCR::Controller::status - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my $dirpath = `ps a -o etime,pid,cmd  | grep c7aocr.pl | grep -v grep `;
    my $jobpid = 'none';
    if( $dirpath =~ m{ (\d+) } ) {
        $jobpid = $1;
    }
    `echo $jobpid > /var/run/c7aocr/jobpids`;

    $c->response->body( $dirpath );
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
