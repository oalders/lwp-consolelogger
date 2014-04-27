package LWP::ConsoleLogger::Easy;

use strict;
use warnings;

use LWP::ConsoleLogger;
use Sub::Exporter -setup => { exports => ['debug_ua'] };

sub debug_ua {
    my $mech   = shift;
    my $logger = LWP::ConsoleLogger->new();
    $mech->default_header(
        'Accept-Encoding' => scalar HTTP::Message::decodable() );

    $mech->add_handler( 'response_done',
        sub { $logger->response_callback( @_ ) } );
    $mech->add_handler( 'request_send',
        sub { $logger->request_callback( @_ ) } );

    return $logger;
}

1;
