package LWP::ConsoleLogger::Easy;

use strict;
use warnings;

use LWP::ConsoleLogger;
use Sub::Exporter -setup => { exports => ['debug_ua'] };

my %VERBOSITY = (
    dump_content => 8,
    dump_cookies => 6,
    dump_headers => 5,
    dump_params  => 4,
    dump_status  => 2,
    dump_text    => 7,
    dump_title   => 3,
    dump_uri     => 1,
);

sub debug_ua {
    my $ua = shift;
    my $level = shift || 10;

    my %args = map { $_ => $VERBOSITY{$_} <= $level } keys %VERBOSITY;
    my $logger = LWP::ConsoleLogger->new(%args);

    add_ua_handlers( $ua, $logger );

    return $logger;
}

sub add_ua_handlers {
    my $ua     = shift;
    my $logger = shift;

    $ua->default_header(
        'Accept-Encoding' => scalar HTTP::Message::decodable() );

    $ua->add_handler(
        'response_done',
        sub { $logger->response_callback(@_) }
    );
    $ua->add_handler(
        'request_send',
        sub { $logger->request_callback(@_) }
    );
}

1;

__END__

# ABSTRACT: Easy LWP tracing and debugging

=pod

=head1 DESCRIPTION

This module gives you the easiest possible introduction to
L<LWP::ConsoleLogger>.  It offers one wrappers around L<LWP::ConsoleLogger>:
C<debug_ua>.  This function allows you to get up and running quickly with just
a couple of lines of code. It instantiates LWP logging and also returns a
L<LWP::ConsoleLogger> object, which you may then tweak to your heart's desire.

=head1 SYNOPSIS

    use LWP::ConsoleLogger::Easy qw( debug_ua );
    use WWW::Mechanize;

    my $mech = WWW::Mechanize->new;
    my $logger = debug_ua( $mech );
    $mech->get(...);

    # now watch the console for debugging output

    # ...
    # stop dumping headers
    $logger->dump_headers( 0 );

    my $quiet_logger = debug_ua( $mech, 1 );

    my $noisy_logger = debug_ua( $mech, 5 );

=head1 FUNCTIONS

=head2 debug_ua( $mech, $verbosity )

When called without a verbosity argument, this function turns on all logging.
I'd suggest going with this to start with and then turning down the verbosity
after that.   This method returns an L<LWP::ConsoleLogger> object, which you
may tweak to your heart's desire.

    my $ua_logger = debug_ua( $mech );
    $ua_logger->content_pre_filter( sub {...} );
    $ua_logger->logger( Log::Dispatch->new(...) );

    $mech->get(...);

You can provide a verbosity level of 0 or more.  (Currently 0 - 8 supported.)
This will turn up the verbosity on your output gradually.  A verbosity of 0
will display nothing.  8 will display all available outputs.

    # don't get too verbose
    my $ua_logger = debug_ua( $mech, 4 );


=head2 EXAMPLES

Please see the "examples" folder in this distribution for more ideas on how to
use this module.

=cut

# ABSTRACT: Start logging your LWP useragent the easy way.
