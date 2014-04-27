#!/usr/bin/env perl

use strict;
use warnings;

use HTTP::Request;
use LWP::ConsoleLogger;
use WWW::Mechanize;

my $mech = WWW::Mechanize->new;
my $logger = LWP::ConsoleLogger->new( dump_text => 1 );

$mech->default_header(
    'Accept-Encoding' => scalar HTTP::Message::decodable() );

$mech->add_handler( 'response_done',
    sub { $logger->response_callback( @_ ) } );
$mech->add_handler( 'request_send', sub { $logger->request_callback( @_ ) } );

$mech->get( 'http://www.nytimes.com?foo=bar' );
$mech->get(
    '/2014/04/24/technology/fcc-new-net-neutrality-rules.html?hp&_r=0' );
