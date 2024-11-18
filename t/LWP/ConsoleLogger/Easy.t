use strict;
use warnings;
use version;

use Data::Printer;
use HTML::FormatText::WithLinks          ();
use LWP::ConsoleLogger::Easy             qw( debug_ua );
use Log::Dispatch                        ();
use Log::Dispatch::Array                 ();
use Module::Runtime                      qw( require_module );
use Path::Tiny                           qw( path );
use Plack::Handler::HTTP::Server::Simple ();
use Plack::Test                          ();
use Plack::Test::Agent                   ();
use Test::Warnings;
use Test::Fatal qw( exception );
use Test::Most import => [qw( diag done_testing is is_deeply ok skip )];
use Try::Tiny      qw( catch try );
use WWW::Mechanize ();

my $lwp  = LWP::UserAgent->new( cookie_jar => {} );
my $mech = WWW::Mechanize->new( autocheck  => 0 );

my @user_agents = ( $lwp, $mech );

my $mojo;
try {
    require_module('Mojo::UserAgent');
    require_module('Mojolicious');

    if ( version->parse($Mojolicious::VERSION) < 7.13 ) {
        die "Mojo version $Mojolicious::VERSION is too low";
    }

    $mojo = Mojo::UserAgent->new;
    push @user_agents, $mojo;
}
catch {
    diag $_;
SKIP: {
        skip 'Mojolicious not installed', 1;
    }
};

my $foo = 'file://' . path('t/test-data/foo.html')->absolute;

foreach my $mech (@user_agents) {
    my $logger = debug_ua($mech);
    ok( $logger->dump_content, 'defaults to highest log level' );
    is(
        exception {
            $mech->get($foo);
        },
        undef,
        'code lives'
    );

    my $silent_logger = debug_ua( $mech, 0 );

    my @dump_attrs = (
        'content', 'cookies', 'headers', 'params', 'status', 'text',
        'title',   'uri',
    );

    for my $suffix (@dump_attrs) {
        my $attr = 'dump_' . $suffix;
        ok( !$silent_logger->$attr, 'silent logger does not ' . $attr );
    }
}

# Check XML parsing
SKIP: {
    skip 'XML test breaks with newer version of Data::Printer', 1, unless version->parse($Data::Printer::VERSION) <= 0.4;
    my $xml  = q[<foo id="1"><bar>baz</bar></foo>];
    my @args = (
        $xml,
        'text/xml',
        sub {
            my $xml = shift;

            # brittle and hackish, but it works
            $xml =~ s{[ \s | + \- \. \\ ]}{}gxms;
            $xml =~ s{'+\z}{};
            $xml =~ s{Text}{};
            my $ref = eval $xml;
            is_deeply(
                $ref, { foo => { bar => 'baz', id => 1 } },
                'XML parsed'
            );
        }
    );
    test_content_lwp(@args);
    test_content_mojo(@args) if $mojo;
}

# Check javascript parsing
{
    my $js = <<'EOF';
var foo = function(bar) {
    var baz = bar();
    console.dir(baz);
    var quux = 'A very long string to go over the cutoff limit of 255 chars. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.'
};
EOF

    my @args = (
        $js,
        'application/javascript',
        sub {
            my $text = shift;
            $text =~ s/-[\s|]+//g;
            ok( $text =~ /^| var baz/m,    'leading whitespace is trimmed' );
            ok( $text =~ /magna al\.\.\./, 'text is cut off at 255 chars' );
        }
    );
    test_content_lwp(@args);
    test_content_mojo(@args) if $mojo;
}

# Check text_pre_filter
{
    my $ua             = LWP::UserAgent->new( cookie_jar => {} );
    my $easy           = debug_ua($ua);
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
        my $app  = sub {
            return [ 200, [ 'Content-Type' => 'text/html' ], [$html] ];
        };

        my $server_agent = Plack::Test::Agent->new(
            app    => $app,
            server => Plack::Handler::HTTP::Server::Simple::,
            ua     => $ua,
        );

        ok( $server_agent->get('/')->is_success, 'GET HTML' );
    }
}

# check POST body parsing that includes a file upload
#
# This will fail with "400 Library does not allow method POST for 'file:'
# URLs", but the point of this is just to produce some output which proves file
# upload fields get displayed.

{
    my $file = 'file://' . path('t/test-data/file-upload.html')->absolute;
    $mech->get($file);
    $mech->form_id('this-form');
    $mech->field( file => 't/test-data/foo.html' );
    $mech->submit('submit batch lookup');
}

done_testing();

sub test_content_lwp {
    my $content      = shift;
    my $content_type = shift;
    my $test_sub     = shift;

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

    my $app = sub {
        return [ 200, [ 'Content-Type' => $content_type ], [$content] ];
    };

    my $server_agent = Plack::Test::Agent->new(
        app    => $app,
        server => Plack::Handler::HTTP::Server::Simple::,
        ua     => $ua,
    );

    ok( $server_agent->get('/')->is_success, 'GET OK with LWP' );

    my $text;
    foreach my $item ( reverse @{$logging_output} ) {
        if ( $item->{message} =~ m{| Text} ) {
            $text = $item->{message};
            last;
        }
    }

    # NOTE: $text passed here is a Text::SimpleTable string, not the bare
    # content.  So your tests need to accommodate this.
    $test_sub->($text);
}

sub test_content_mojo {
    my $content      = shift;
    my $content_type = shift;
    my $test_sub     = shift;

    my $ua             = Mojo::UserAgent->new;
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

    require_module('Mojolicious');
    my $app = Mojolicious->new;
    Mojo::UserAgent::Server->app($app);
    $app->routes->get('/')->to(
        cb => sub {
            my $c = shift;
            $c->res->headers->content_type($content_type);
            $c->render( text => $content );
        }
    );

    ok( $ua->get('/')->res->is_success, 'GET OK with Mojo::UserAgent' );

    my $text;
    foreach my $item ( reverse @{$logging_output} ) {
        if ( $item->{message} =~ m{| Text} ) {
            $text = $item->{message};
            last;
        }
    }

    # NOTE: $text passed here is a Text::SimpleTable string, not the bare
    # content.  So your tests need to accommodate this.
    $test_sub->($text);
}
