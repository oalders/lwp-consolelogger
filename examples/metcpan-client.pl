#!/usr/bin/env perl

use strict;
use warnings;

use Devel::SimpleTrace;
use HTTP::Tiny::Mech;
use LWP::ConsoleLogger::Easy qw( debug_ua );
use MetaCPAN::Client;
use WWW::Mechanize;

my $ua
    = WWW::Mechanize->new( headers => { 'Accept-Encoding' => 'identity' } );
my $logger = debug_ua( $ua );

my $wrapped_ua = HTTP::Tiny::Mech->new( mechua => $ua );

my $mcpan = MetaCPAN::Client->new( ua => $wrapped_ua );
my $author = $mcpan->author( 'XSAWYERX' );
