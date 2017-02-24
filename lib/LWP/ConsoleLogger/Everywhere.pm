package LWP::ConsoleLogger::Everywhere;
use strict;
use warnings;

use LWP::ConsoleLogger::Easy qw( debug_ua );
use LWP::UserAgent;
use Class::Method::Modifiers ();

no warnings 'once';

Class::Method::Modifiers::install_modifier(
    'LWP::UserAgent',
    'around',
    'new' => sub {
        my $orig = shift;
        my $self = shift;

        my $ua = $self->$orig(@_);
        debug_ua($ua);

        return $ua;
    }
);

1;

__END__

# ABSTRACT: LWP tracing everywhere

=pod

=head1 DESCRIPTION

This module turns on C<LWP::ConsoleLogger::Easy> debugging for every L<LWP::UserAgent>
based user agent anywhere in your code. It doesn't matter what package or class it is in,
or if you have access to the object itself. All you need to do is C<use> this module
anywhere in your code and it will work.

It cannot be configured unless you have access to the user agent in question.

=head1 SYNOPSIS

    use LWP::ConsoleLogger::Everywhere;

    # somewhere deep down in the guts of your program
    # there is some other module that creates an LWP::UserAgent
    # and now it will tell you what it's up to

    # Redact sensitive data for all user agents
    $ENV{LWPCL_REDACT_HEADERS} = 'Authorization,Foo,Bar';
    $ENV{LWPCL_REDACT_PARAMS} = 'seekrit,password,credit_card';

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

=head1 SEE ALSO

For more information or if you want more detailed control see L<LWP::ConsoleLogger>.

=cut
