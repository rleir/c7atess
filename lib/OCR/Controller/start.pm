package OCR::Controller::start;
use Moose;
use namespace::autoclean;
use OCR::Ocrdb qw( pushOCRjob );

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
    my $starttime = time();

    # remove any leading spaces
    $treePath =~ s/^\s+//;
    
    # start a job
    $c->log->debug( "starting  $treePath $collID ") if( $c->log->is_debug);

#    $collID = system("./DoJob.pl --input=$treePath --verbose & ");
    my $ret = pushOCRjob( "Dashboard", 
                          5, 
                          'richard@c7a.ca',  # this should come from the form
                          $treePath, 
                          " ./DoImage.pl --input={} --lang=eng --verbose ", 
                          $starttime,
                          $collID );

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
