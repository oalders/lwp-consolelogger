use strict;
use warnings;

use HTTP::Headers      ();
use HTTP::Request      ();
use HTTP::Response     ();
use Log::Dispatch      ();
use LWP::ConsoleLogger ();
use Test::More import => [qw( like ok subtest unlike )];
use Test::Warnings;

# Anonymous fake UA — has no title() and a no-op cookie_jar
{
    package Fake::UA;
    sub new        { bless {}, shift }
    sub cookie_jar { undef }
    sub can { my ( $s, $m ) = @_; $m eq 'title' ? 0 : $s->SUPER::can($m) }
}

sub make_logger {
    my $captured = shift;    # arrayref the caller wants populated
    return Log::Dispatch->new(
        outputs => [
            [
                'Code',
                min_level => 'debug',
                code      => sub {
                    my %args = @_;
                    push @{$captured}, $args{message};
                },
            ],
        ],
    );
}

subtest 'userinfo credentials are dropped from the logged URI' => sub {
    my @captured;
    my $cl = LWP::ConsoleLogger->new(
        logger       => make_logger( \@captured ),
        dump_content => 0,
        dump_headers => 0,
        dump_params  => 0,
        dump_text    => 0,
    );

    my $req = HTTP::Request->new(
        GET => 'https://john.doe:s3cr3t@example.com/path?token=abc' );
    $cl->request_callback( $req, Fake::UA->new );

    my $all = join "\n", @captured;
    like( $all, qr{https://example\.com/path}, 'host and path still logged' );
    unlike( $all, qr/s3cr3t/,    'password is not logged' );
    unlike( $all, qr/john\.doe/, 'username is not logged' );
    unlike( $all, qr/token=abc/, 'query string is still stripped' );
};

subtest 'Authorization header is redacted by default (non-pretty)' => sub {
    my @captured;
    my $cl = LWP::ConsoleLogger->new(
        logger       => make_logger( \@captured ),
        pretty       => 0,
        dump_content => 0,
        dump_text    => 0,
    );

    my $req = HTTP::Request->new( GET => 'http://example.com/' );
    $req->header( Authorization => 'Basic Zm9vOmJhcg==' );
    my $res = HTTP::Response->new(
        200, 'OK', HTTP::Headers->new( 'Content-Type' => 'text/plain' ),
        'body'
    );
    $res->request($req);

    $cl->response_callback( $res, Fake::UA->new );

    my $all = join "\n", @captured;
    like(
        $all, qr/Authorization: \[REDACTED\]/,
        'Authorization is redacted'
    );
    unlike( $all, qr/Zm9vOmJhcg/, 'the credential value is not logged' );
};

subtest 'Authorization header is redacted by default (pretty)' => sub {
    my @captured;
    my $cl = LWP::ConsoleLogger->new(
        logger       => make_logger( \@captured ),
        pretty       => 1,
        dump_content => 0,
        dump_text    => 0,
    );

    my $req = HTTP::Request->new( GET => 'http://example.com/' );
    $req->header( Authorization => 'Basic Zm9vOmJhcg==' );
    my $res = HTTP::Response->new(
        200, 'OK', HTTP::Headers->new( 'Content-Type' => 'text/plain' ),
        'body'
    );
    $res->request($req);

    $cl->response_callback( $res, Fake::UA->new );

    my $all = join "\n", @captured;
    like( $all, qr/\[REDACTED\]/, 'Authorization value shown as [REDACTED]' );
    unlike( $all, qr/Zm9vOmJhcg/, 'the credential value is not logged' );
};

subtest 'user-supplied LWPCL_REDACT_HEADERS is merged with the default' =>
    sub {
    local $ENV{LWPCL_REDACT_HEADERS} = 'X-Secret';
    my @captured;
    my $cl = LWP::ConsoleLogger->new(
        logger       => make_logger( \@captured ),
        pretty       => 0,
        dump_content => 0,
        dump_text    => 0,
    );

    my $req = HTTP::Request->new( GET => 'http://example.com/' );
    $req->header( Authorization => 'Basic Zm9vOmJhcg==' );
    $req->header( 'X-Secret'    => 'do-not-show' );
    my $res = HTTP::Response->new(
        200, 'OK', HTTP::Headers->new( 'Content-Type' => 'text/plain' ),
        'body'
    );
    $res->request($req);

    $cl->response_callback( $res, Fake::UA->new );

    my $all = join "\n", @captured;
    like( $all, qr/Authorization: \[REDACTED\]/, 'default still applies' );
    like( $all, qr/X-Secret: \[REDACTED\]/, 'env-supplied header added' );
    unlike( $all, qr/do-not-show/, 'env-supplied header value not logged' );
    };

subtest 'schemes without userinfo (file://) do not crash' => sub {
    my @captured;
    my $cl = LWP::ConsoleLogger->new(
        logger       => make_logger( \@captured ),
        dump_content => 0,
        dump_headers => 0,
        dump_params  => 0,
        dump_text    => 0,
    );

    my $req = HTTP::Request->new( GET => 'file:///tmp/foo.html' );
    ok(
        eval { $cl->request_callback( $req, Fake::UA->new ); 1 },
        'file:// URI is logged without dying'
    );
    like( join( "\n", @captured ), qr{file:///tmp/foo\.html}, 'URI logged' );
};

done_testing;
