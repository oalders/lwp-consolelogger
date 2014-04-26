use strict;
use warnings;

use DDP;
use Devel::SimpleTrace;
use LWP::ConsoleLogger;
use Test::Most;
use LWP::UserAgent;
use WWW::Mechanize;
use HTTP::Request;

#my $mech = LWP::UserAgent->new(cookie_jar  => {});
my $mech = WWW::Mechanize->new;
my $logger = LWP::ConsoleLogger->new( dump_text => 1 );

$mech->default_header( 'Accept-Encoding' => scalar HTTP::Message::decodable() );

#$mech->add_handler( "request_send",  sub { shift->dump; return } );
#$mech->add_handler( "response_done", sub { shift->dump; return } );

$mech->add_handler( 'response_done', sub { $logger->response_callback( @_ ) } );
$mech->add_handler( 'request_send', sub { $logger->request_callback( @_ ) } );

#$mech->get( 'http://www.nytimes.com?foo=bar' );
#$mech->get('http://www.nytimes.com/2014/04/24/technology/fcc-new-net-neutrality-rules.html?hp&_r=0');
$mech->get('http://wundercounter.com?foo=bar&foo=baz&asdasdfasdfsfd=asasdfasdfasdf');


ok( 1 );
done_testing();
