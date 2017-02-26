use strict;
use warnings;

use Capture::Tiny 'capture_stderr';
use Path::Tiny qw( path );
use Test::FailWarnings;
use Test::Fatal qw( exception );
use Test::More;
use LWP::UserAgent;
use WWW::Mechanize;

use LWP::ConsoleLogger::Everywhere;

my $foo = 'file://' . path('t/test-data/foo.html')->absolute;

my $lwp  = LWP::UserAgent->new( cookie_jar => {} );
my $mech = WWW::Mechanize->new( autocheck  => 0 );

foreach my $ua ( $lwp, $mech ) {
    my $stderr = capture_stderr sub {
        is(
            exception {
                $mech->get($foo);
            },
            undef,
            'code lives'
        );
    };
    ok $stderr, 'there was a dump';
}

{

    package Foo::Bar;

    our $lwp  = LWP::UserAgent->new( cookie_jar => {} );
    our $mech = WWW::Mechanize->new( autocheck  => 0 );
}

foreach my $ua ( $Foo::Bar::lwp, $Foo::Bar::mech ) {
    my $stderr = capture_stderr sub {
        is(
            exception {
                $mech->get($foo);
            },
            undef,
            'code lives'
        );
    };
    diag $stderr;
    ok $stderr, 'there was a dump';
}

is( ( grep { $_->isa('LWP::ConsoleLogger') } @{ LWP::ConsoleLogger::Everywhere->loggers } ),
    4, 'all loggers are stored' );

done_testing();
