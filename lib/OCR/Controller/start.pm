package OCR::Controller::start;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

OCR::Controller::start - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my $treePath = $c->request->body_data->{"treePath"} // '';
    my $collID   = $c->request->body_data->{"collID"}   // '';

    # remove any leading spaces
    $treePath =~ s/^\s+//;
    
    # start a job
    $c->log->debug( "starting  $treePath $collID ") if( $c->log->is_debug);

    $collID = system("./c7aocr.pl --input=$treePath --verbose & ");

    $c->response->body("treePath $treePath $collID");
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