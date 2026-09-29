package TestLogger;

use strict;
use warnings;

use Exporter      qw( import );
use Log::Dispatch ();

our @EXPORT_OK = qw( capturing_logger null_logger );

# A logger that discards everything. Use it when a test only needs the logging
# code path exercised and does not assert on the output, so nothing leaks to
# STDERR during the run.
sub null_logger {
    return Log::Dispatch->new(
        outputs => [ [ 'Null', min_level => 'debug' ] ],
    );
}

# A logger that captures messages into an array. Returns the logger and a
# reference to the array it writes to, so a test can assert on the output
# without any of it reaching the screen.
sub capturing_logger {
    my $messages = [];
    my $logger   = Log::Dispatch->new(
        outputs => [
            [
                'Array', min_level => 'debug', name => 'test',
                array => $messages
            ],
        ],
    );
    return ( $logger, $messages );
}

1;
