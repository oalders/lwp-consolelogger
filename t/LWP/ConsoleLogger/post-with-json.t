use strict;
use warnings;
use lib 't/lib';

use HTTP::Request                        ();
use LWP::ConsoleLogger::Easy             qw( debug_ua );
use LWP::UserAgent                       ();
use Plack::Handler::HTTP::Server::Simple ();
use Plack::Test::Agent                   ();
use Test::LWP::UserAgent                 ();
use Test::More import => [qw( done_testing ok subtest )];
use TestLogger qw( null_logger );

my $ua = LWP::UserAgent->new( cookie_jar => {} );
debug_ua($ua)->logger( null_logger() );

my $test_ua = Test::LWP::UserAgent->new;
debug_ua($test_ua)->logger( null_logger() );

$test_ua->map_response(
    qr{example.com/success},
    HTTP::Response->new(
        200, 'OK', [ 'Content-Type' => 'text/plain' ], 'Content is queen'
    )
);

my $app = sub {
    return [
        200, [ 'Content-Type' => 'application/json' ],
        ['{"foo":"bar"}']
    ];
};

my $server_agent = Plack::Test::Agent->new(
    app    => $app,
    server => Plack::Handler::HTTP::Server::Simple::,
    ua     => $ua,
);

# mostly just do a visual check that POST params are parsed

subtest 'check POST body parsing of JSON' => sub {
    ok(
        $server_agent->post(
            '/', Content_Type => 'application/json',
            Content => '{"aaa":"bbb"}'
        ),
        'POST param parsing'
    );
};

subtest 'use HTTP::Request' => sub {
    my $req = HTTP::Request->new(
        POST => 'http://example.com/success',
        [
            'Content-Type' => 'application/json',
        ],
        '{"xxx":"yyy"}'
    );

    my $response = $test_ua->request($req);
    ok( $response, 'request sent' );
};

done_testing();
