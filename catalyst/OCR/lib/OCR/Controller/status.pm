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
    my $dirpath = `ps -aef | grep c7aocr.pl | grep -m 1 input `;

#     @args = ("ps -aef | grep c7aocr.pl", "", "");
# my $dirpath = system(@args) == 0
 ##   or $dirpath = "system failed: $?"
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
