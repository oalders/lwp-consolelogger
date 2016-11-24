use strict;
use warnings;

use LWP::ConsoleLogger::Easy qw( debug_ua );
use LWP::UserAgent     ();
use Plack::Test::Agent ();
use Test::More;

my $ua = LWP::UserAgent->new( cookie_jar => {} );
debug_ua($ua);

subtest 'check POST body parsing of JSON' => sub {
    my $app = sub {
        return [
            200, [ 'Content-Type' => 'application/json' ],
            ['{"foo":"bar"}']
        ];
    };

    my $server_agent = Plack::Test::Agent->new(
        app    => $app,
        server => 'HTTP::Server::Simple',
        ua     => $ua,
    );

    # mostly just do a visual check that POST params are parsed
    ok(
        $server_agent->post(
            '/', Content_Type => 'application/json',
            Content => '{"aaa":"bbb"}'
        ),
        'POST param parsing'
    );
};

done_testing();
