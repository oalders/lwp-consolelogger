use strict;
use warnings;

use HTTP::Request;
use LWP::ConsoleLogger;
use LWP::UserAgent;
use Path::Tiny qw( path );
use Test::Fatal qw( exception );
use Test::Most;
use WWW::Mechanize;

my @mech = ( LWP::UserAgent->new( cookie_jar => {} ), WWW::Mechanize->new );
my $logger = LWP::ConsoleLogger->new( dump_text => 1 );
ok( $logger, 'logger compiles' );

foreach my $mech ( @mech ) {
    is( exception { get_local_file( $mech ) }, undef, 'code lives' );
}

sub get_local_file {
    my $mech = shift;
    $mech->default_header(
        'Accept-Encoding' => scalar HTTP::Message::decodable() );

    $mech->add_handler( 'response_done',
        sub { $logger->response_callback( @_ ) } );
    $mech->add_handler( 'request_send',
        sub { $logger->request_callback( @_ ) } );

    $mech->get( 'file://' . path( "t/test-data/foo.html" )->absolute );
}

done_testing();
