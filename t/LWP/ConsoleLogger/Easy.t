use strict;
use warnings;

use LWP::ConsoleLogger::Easy qw( debug_ua );
use Path::Tiny qw( path );
use Test::Fatal qw( exception );
use Test::Most;
use WWW::Mechanize;

my @mech = ( LWP::UserAgent->new( cookie_jar => {} ), WWW::Mechanize->new );

my $foo = 'file://' . path( 't/test-data/foo.html' )->absolute;

foreach my $mech ( @mech ) {
    my $logger = debug_ua( $mech );
    is( exception {
            $mech->get( $foo );
        },
        undef,
        'code lives'
    );
}

{
    my $mech = LWP::UserAgent->new;
    my $logger = debug_ua( $mech );
    $logger->dump_content( 1 );
    $logger->dump_text( 1 );
    $mech->get( $foo );
}

done_testing();
