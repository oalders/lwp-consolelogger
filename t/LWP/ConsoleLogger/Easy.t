use strict;
use warnings;

use Data::Printer;
use HTML::FormatText::WithLinks;
use LWP::ConsoleLogger::Easy qw( debug_ua );
use Log::Dispatch;
use Log::Dispatch::Array;
use Path::Tiny qw( path );
use Plack::Test;
use Plack::Test::Agent;
use Test::FailWarnings;
use Test::Fatal qw( exception );
use Test::Most;
use WWW::Mechanize;

my $lwp = LWP::UserAgent->new( cookie_jar => {} );
my $mech = WWW::Mechanize->new();

my $foo = 'file://' . path('t/test-data/foo.html')->absolute;

foreach my $mech ( $lwp, $mech ) {
    my $logger = debug_ua($mech);
    is(
        exception {
            $mech->get($foo);
        },
        undef,
        'code lives'
    );
}

# Check XML parsing
{
    my $ua             = LWP::UserAgent->new( cookie_jar => {} );
    my $logger         = debug_ua($ua);
    my $logging_output = [];

    my $ld = Log::Dispatch->new(
        outputs => [ [ 'Screen', min_level => 'debug', newline => 1, ] ] );

    $ld->add(
        Log::Dispatch::Array->new(
            name      => 'test',
            min_level => 'debug',
            array     => $logging_output
        )
    );

    $logger->logger($ld);

    {
        my $xml = q[<foo id="1"><bar>baz</bar></foo>];
        my $app
            = sub { return [ 200, [ 'Content-Type' => 'text/xml' ], [$xml] ] };

        my $server_agent = Plack::Test::Agent->new(
            app    => $app,
            server => 'HTTP::Server::Simple',
            ua     => $ua,
        );

        ok( $server_agent->get('/')->is_success, 'GET XML' );
    }
    {
        my $xml;

        foreach my $item ( reverse @{$logging_output} ) {
            if ( $item->{message} =~ m{| Text} ) {
                $xml = $item->{message};
                last;
            }
        }

        # brittle and hackish, but it works
        $xml =~ s{[ \s | + \- ' \. \\ ]}{}gxms;
        $xml =~ s{Text}{};
        my $ref = eval $xml;
        is_deeply( $ref, { foo => { bar => "baz", id => 1 } }, 'XML parsed' );
    }
}

# Check text_pre_filter
{
    my $ua             = LWP::UserAgent->new( cookie_jar => {} );
    my $easy         = debug_ua($ua);
    my $logging_output = [];

    $easy->logger->add(
        Log::Dispatch::Array->new(
            name      => 'test',
            min_level => 'debug',
            array     => $logging_output
        )
    );

    $easy->text_pre_filter(
        sub {
            my $text      = shift;
            my $formatted = HTML::FormatText::WithLinks->new()->parse($text);
            return ( $formatted, 'text/plain' );
        }
    );

    {
        my $html = q[<ul><li>one</li><li>two</li></ul>];
        my $app
            = sub { return [ 200, [ 'Content-Type' => 'text/html' ], [$html] ] };

        my $server_agent = Plack::Test::Agent->new(
            app    => $app,
            server => 'HTTP::Server::Simple',
            ua     => $ua,
        );

        ok( $server_agent->get('/')->is_success, 'GET HTML' );
    }
}

done_testing();
