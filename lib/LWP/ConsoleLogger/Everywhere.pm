package LWP::ConsoleLogger::Everywhere;
use strict;
use warnings;

our $VERSION = '1.000001';

use Class::Method::Modifiers ();
use LWP::ConsoleLogger::Easy qw( debug_ua );
use Module::Runtime          qw( require_module );
use Try::Tiny                qw( try );
use Log::Dispatch            ();
no warnings 'once';

my $loggers;
my $dispatch_logger;

{
    my $key = "LWPCL_LOGFILE";
    if ( exists $ENV{$key} && $ENV{$key} ) {
        my $filename = $ENV{$key};
        $dispatch_logger = Log::Dispatch->new(
            outputs => [
                [ 'File', min_level => 'debug', filename => $filename ],
            ],
        );
    }
}

my $code_injection = sub {
    my $orig = shift;
    my $self = shift;

    my $ua       = $self->$orig(@_);
    my $debug_ua = debug_ua($ua);
    $debug_ua->logger($dispatch_logger) if $dispatch_logger;
    push @{$loggers}, $debug_ua;
    return $ua;
};

try {
    require_module('LWP::UserAgent');
    Class::Method::Modifiers::install_modifier(
        'LWP::UserAgent', 'around',
        'new' => $code_injection
    );
};

try {
    require_module('Mojo::UserAgent');
    Class::Method::Modifiers::install_modifier(
        'Mojo::UserAgent', 'around',
        'new' => $code_injection
    );
};

sub loggers {
    return $loggers;
}

sub set {
    my $class   = shift;
    my $setting = shift;

    foreach my $logger ( @{$loggers} ) {
        $logger->$setting(@_);
    }

    return;
}

1;

__END__

# ABSTRACT: LWP tracing everywhere

=pod

=head1 DESCRIPTION

This module turns on L<LWP::ConsoleLogger::Easy> debugging for every L<LWP::UserAgent> or L<Mojo::UserAgent>
based user agent anywhere in your code. It doesn't matter what package or class it is in,
or if you have access to the object itself. All you need to do is C<use> this module
anywhere in your code and it will work.

You can access and configure the loggers individually after they have been created
using the C<loggers> class method. To change all of them at once, use the C<set> class
method instead.

See
L<https://www.olafalders.com/2021/12/01/observing-network-traffic-with-lwp-consolelogger-everywhere/>
for a practical example of how to use this module.

=head1 SYNOPSIS

    use LWP::ConsoleLogger::Everywhere;

    # somewhere deep down in the guts of your program
    # there is some other module that creates an LWP::UserAgent
    # and now it will tell you what it's up to

    # somewhere else you can access and fine-tune those loggers
    # individually:
    my $loggers = LWP::ConsoleLogger::Everywhere->loggers;
    $loggers->[0]->pretty(0);

    # or all of them at once:
    LWP::ConsoleLogger::Everywhere->set( pretty => 1);

    # Redact sensitive data for all user agents
    $ENV{LWPCL_REDACT_HEADERS} = 'Authorization,Foo,Bar';
    $ENV{LWPCL_REDACT_PARAMS} = 'seekrit,password,credit_card';

    # Or observe without changing your code
    PERL5OPT="-MLWP::ConsoleLogger::Everywhere" carton install

    perl -MLWP::ConsoleLogger::Everywhere my-script.pl

=head1 CLASS METHODS

=head2 set( <setting> => <value> )

    LWP::ConsoleLogger::Everywhere->set( dump_content => 0 );

This class method changes the given setting on all logger objects that have been created
so far. The first argument is the accessor name of the setting you want to change, and the
second argument is the new value. This cannot be used to access current values. See
L<LWP::ConsoleLogger#SUBROUTINES/METHODS> for what those settings are.

=head2 loggers

    my $loggers = LWP::ConsoleLogger::Everywhere->loggers;
    foreach my $logger ( @{ $loggers } ) {
        # stop dumping headers
        $logger->dump_headers( 0 );
    }

This class method returns an array reference of all L<LWP::ConsoleLogger> objects that have
been created so far, with the newest one last. You can use them to fine-tune settings. If there
is more than one user agent in your application you will need to figure out which one is which.
Since this is for debugging only, trial and error is a good strategy here.

=head1 ENVIRONMENT VARIABLES

=head2 LWPCL_LOGFILE

By default all data will be dumped to your console (as the name of this module implies) using
L<Log::Dispatch>. You may change this behavior though. The general approach is to do it from
within your script, for example like this:

    use LWP::ConsoleLogger::Everywhere;
    my $loggers = LWP::ConsoleLogger::Everywhere->loggers;
    my $log_dispatch = Log::Dispatch->new(
      outputs => [
          [ 'File',   min_level => 'debug', filename => 'log_file.txt' ],
          [ 'Screen', min_level => 'debug' ],
      ],
    );
    foreach my $logger ( @{ $loggers } ) {
        $logger->logger($log_dispatch);
    }

The second approach is simpler and is done via an environment variable, for example you can run
your script like this:

    LWPCL_LOGFILE=foo.log perl -MLWP::ConsoleLogger::Everywhere foo.pl

this will be equivalent to the first approach with the following Log::Dispatch logger:

    my $log_dispatch = Log::Dispatch->new(
        outputs => [ [ 'File', min_level => 'debug', filename => 'foo.log' ]  ],
    );


=head1 CAVEATS

If there are several different user agents in your application, you will get debug
output from all of them. This could be quite cluttered.

Since L<LWP::ConsoleLogger::Everywhere> does its magic during compile time it will
most likely catch every user agent in your application, unless
you C<use LWP::ConsoleLogger::Everywhere> inside a file that gets loaded at runtime.
If the user agent you wanted to debug had already been created at that time it
cannot hook into the constructor any more.

L<LWP::ConsoleLogger::Everywhere> works by catching new user agents directly in
L<LWP::UserAgent> when they are created. That way all properly implemented sub classes
like L<WWW::Mechanize> will go through it. But if you encounter one that installs its
own handlers into the user agent after calling C<new> in L<LWP::UserAgent>
that might overwrite the ones L<LWP::ConsoleLogger> installed.

L<LWP::ConsoleLogger::Everywhere> will keep references to all user agents that were
ever created during for the lifetime of your application. If you have a lot of lexical
user agents that you recycle all the time they will not actually go away and might
consume memory.

=head1 SEE ALSO

For more information or if you want more detailed control see L<LWP::ConsoleLogger>.

=cut
