package OCR::Controller::pause;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

OCR::Controller::pause - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
#    my $sigName = $c->request->parameters->{"sigName"} // '';
    my $sigName = $c->request->body_data->{"sigName"} // '';

    my $jobpid = 'none';
    $jobpid = `cat /var/run/ocr/jobpids`;
    $c->log->debug( "params $sigName $jobpid ") if( $c->log->is_debug);

    my $rslt = "try again";
    if( !($jobpid eq 'none')) {
        $rslt = `kill -s $sigName $jobpid`;
        $c->log->debug( "pid $rslt ") if( $c->log->is_debug);
    } else {
        $c->log->debug( "none ") if( $c->log->is_debug);
    }
    $c->response->body("pause: $rslt");
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
