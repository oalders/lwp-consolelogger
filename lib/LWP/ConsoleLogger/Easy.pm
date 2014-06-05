package LWP::ConsoleLogger::Easy;

use strict;
use warnings;

use LWP::ConsoleLogger;
use Sub::Exporter -setup => { exports => ['debug_ua'] };

sub debug_ua {
    my $mech   = shift;
    my $logger = LWP::ConsoleLogger->new(
        dump_content => 1,
        dump_cookies => 1,
        dump_headers => 1,
        dump_params  => 1,
        dump_text    => 1,
    );

    $mech->default_header(
        'Accept-Encoding' => scalar HTTP::Message::decodable() );

    $mech->add_handler( 'response_done',
        sub { $logger->response_callback( @_ ) } );
    $mech->add_handler( 'request_send',
        sub { $logger->request_callback( @_ ) } );

    return $logger;
}

1;

__END__

=pod

=head1 DESCRIPTION

This module gives you the easiest possible (and the most verbose) introduction
to L<LWP::ConsoleLogger>.  It turns on all logging by default.  I'd suggest
going with the defaults to start with and then turning down the verbosity after
that.

=head1 SYNOPSIS

    use LWP::ConsoleLogger::Easy qw( debug_ua );
    use WWW::Mechanize;

    my $mech = WWW::Mechanize->new;
    my $logger = debug_ua( $mech );
    $mech->get(...);

    # now watch the console for debugging output

=head1 FUNCTIONS

=head2 debug_ua

This module exports one function: debug_ua().  It's essentially an easy wrapper
around L<LWP::ConsoleLogger>, allowing you to get up and running quickly with
just a couple of lines of code.  This method instantiates LWP logging and also
returns an LWP::ConsoleLogger object, which you may then tweak to your heart's
desire.

    my $ua_logger = debug_ua( $mech );
    $ua_logger->content_pre_filter( sub {...} );
    $ua_logger->logger( Log::Dispatch->new(...) );

    $mech->get(...);

=cut

# ABSTRACT: Start logging your LWP useragent the easy way.
