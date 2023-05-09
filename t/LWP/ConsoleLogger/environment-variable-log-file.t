use strict;
use warnings;
use version;

use Module::Runtime qw( require_module );
use Test::More import => [qw( diag done_testing is ok skip )];
use Try::Tiny  qw( catch try );
use Path::Tiny qw( path tempdir );
use File::Spec ();
my $tempdir     = tempdir();
my $log_fn_path = $tempdir->child('foo.log');
my $log_fn      = $log_fn_path->stringify;
local $ENV{LWPCL_LOGFILE} = $log_fn;
require_module('LWP::ConsoleLogger::Everywhere');
require_module('WWW::Mechanize');
my $url    = 'file://' . path('t/test-data/foo.html')->absolute;
my $mech   = WWW::Mechanize->new;
my $result = $mech->get($url);
ok( -f $log_fn, 'logfile exists' );
my $data = $log_fn_path->slurp();
diag("logfile data: '$data'");
ok( $data =~ /^GET file:/, 'logfile content ok' );
done_testing();
