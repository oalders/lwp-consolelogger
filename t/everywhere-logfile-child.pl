use strict;
use warnings;

# Loaded for its import-time side effect (installs logging into every UA and
# reads $ENV{LWPCL_LOGFILE}); imports nothing, so pin it past perlimports.
use LWP::ConsoleLogger::Everywhere ();           ## no perlimports
use LWP::UserAgent                 ();
use Path::Tiny                     qw( path );

my $url = 'file:///' . path('t/test-data/unicode.html')->absolute;
my $ua  = LWP::UserAgent->new;
$ua->get($url);
exit 0;
