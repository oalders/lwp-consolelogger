package LWP::ConsoleLogger::Easy;

use strict;
use warnings;

use LWP::ConsoleLogger;
use Module::Load::Conditional qw( can_load );
use Sub::Exporter -setup => { exports => ['debug_ua'] };
use String::Trim;

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

    if ( can_load( modules => { 'HTML::FormatText::Lynx' => 23 } ) ) {
        $logger->text_pre_filter(
            sub {
                my $text         = shift;
                my $content_type = shift;
                my $base_url     = shift;

                return $text
                    unless $content_type && $content_type =~ m{html}i;

                return (
                    trim(
                        HTML::FormatText::Lynx->format_string(
                            $text,
                            base => $base_url,
                        )
                    ),
                    'text/plain'
                );
            }
        );
    }

    return $logger;
}

sub add_ua_handlers {
    my $ua     = shift;
    my $logger = shift;

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

If you're able to install L<HTML::FormatText::Lynx> then you'll get highly
readable HTML to text conversions.

=head1 SYNOPSIS

    use LWP::ConsoleLogger::Easy qw( debug_ua );
    use WWW::Mechanize;

    my $mech = WWW::Mechanize->new;
    my $logger = debug_ua( $mech );
    $mech->get('https://google.com');

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

=head2 CAVEATS

Text formatting now defaults to attempting to use L<HTML::FormatText::Lynx> to
format HTML as text.  If you do not have this installed, we'll fall back to
using HTML::Restrict to remove any HTML tags which you have not specifically
whitelisted.

If you have L<HTML::FormatText::Lynx> installed, but you don't want to use it,
override the default filter:

    my $logger = debug_ua( $mech );
    $logger->text_pre_filter( sub { return shift } );

=head2 EXAMPLES

Please see the "examples" folder in this distribution for more ideas on how to
use this module.

=cut

# ABSTRACT: Start logging your LWP useragent the easy way.
