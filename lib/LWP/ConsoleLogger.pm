use strict;
use warnings;

package LWP::ConsoleLogger;

use DateTime;
use Email::MIME;
use Email::MIME::ContentType qw( parse_content_type );
use HTML::Restrict;
use HTTP::CookieMonster;
use Log::Dispatch;
use Moose;
use MooseX::StrictConstructor;
use Term::Size::Any qw( chars );
use Text::SimpleTable::AutoWidth;
use URI::Query;
use URI::QueryParam;

sub BUILD {
    my $self = shift;
    $Text::SimpleTable::AutoWidth::WIDTH_LIMIT = $self->term_width();
}

has content_pre_filter => (
    is  => 'rw',
    isa => 'CodeRef',
);

has dump_content => (
    is      => 'rw',
    default => 0,
);

has dump_cookies => (
    is      => 'rw',
    default => 0,
);

has dump_headers => (
    is      => 'rw',
    default => 1,
);

has dump_params => (
    is      => 'rw',
    default => 1,
);

has dump_text => (
    is      => 'rw',
    default => 1,
);

has html_restrict => (
    is      => 'rw',
    lazy    => 1,
    default => sub { HTML::Restrict->new },
);

has logger => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        return Log::Dispatch->new(
            outputs => [ [ 'Screen', min_level => 'debug', newline => 1, ], ],
        );
    },
);

has term_width => (
    is       => 'rw',
    required => 0,
    lazy     => 1,
    trigger  => \&_term_set,
    builder  => '_build_term_width',
);

has text_pre_filter => (
    is  => 'rw',
    isa => 'CodeRef',
);

sub _term_set {
    my $self  = shift;
    my $width = shift;
    $Text::SimpleTable::AutoWidth::WIDTH_LIMIT = $width;
}

sub request_callback {
    my $self = shift;
    my $req  = shift;
    my $ua   = shift;

    my $uri_without_query = $req->uri->clone;
    $uri_without_query->query( undef );
    $self->logger->debug( $req->method . q{ } . $uri_without_query . "\n" );
    $self->_log_params( $req );

    $self->_log_headers( 'request', $req->headers );

    return;
}

sub response_callback {
    my $self = shift;
    my $res  = shift;
    my $ua   = shift;

    $self->logger->debug( $res->status_line . "\n" );
    $self->logger->debug( 'Title: ' . $ua->title . "\n" )
        if $ua->can( 'title' ) && $ua->title;
    $self->_log_headers( 'response', $res->headers );
    $self->_log_cookies( 'response', $ua->cookie_jar );

    $self->_log_content( $res, $res->header( 'Content-Type' ) );
    $self->_log_text( $res, $res->header( 'Content-Type' ) );
    return;
}

sub _log_headers {
    my ( $self, $type, $headers ) = @_;

    return if !$self->dump_headers;

    my $t = Text::SimpleTable::AutoWidth->new();
    $t->captions( [ 'Header Name', 'Value' ] );

    foreach my $name ( sort $headers->header_field_names ) {
        next if $name eq 'Cookie' || $name eq 'Set-Cookie';
        $t->row( $name, $headers->header( $name ) );
    }

    $self->logger->debug( ucfirst( $type ) . " Headers:\n" . $t->draw );
}

sub _log_params {
    my ( $self, $req ) = @_;

    return if !$self->dump_params;

    my %params;
    my $uri = $req->uri;

    if ( $req->method eq 'GET' ) {
        my @params = $uri->query_param;
        return unless @params;

        $params{$_} = [ $uri->query_param( $_ ) ] for @params;
    }

    else {
        # this block mostly cargo-culted from HTTP::Request::Params
        my $mime = Email::MIME->new( $req->as_string );

        foreach my $part ( $mime->parts ) {
            $part->disposition_set( 'text/plain' );    # for easy parsing

            my $disp    = $part->header( 'Content-Disposition' );
            my $ct      = parse_content_type( $disp );
            my $name    = $ct->{attributes}->{name};
            my $content = $part->body;

            $content =~ s/\r\n$//;
            my $query = URI::Query->new( $content );
            %params = %{ $query->hash_arrayref };
            last if keys %params;
        }
    }

    my $t = Text::SimpleTable::AutoWidth->new();
    $t->captions( [ 'Key', 'Value' ] );
    foreach my $name ( sort keys %params ) {
        my @values = @{ $params{$name} };
        $t->row( $name, $_ ) for sort @values;
    }

    $self->logger->debug( " Params:\n" . $t->draw );
}

sub _log_cookies {
    my $self = shift;
    my $type = shift;
    my $jar  = shift;

    return if !$self->dump_cookies || !$jar;

    my $monster = HTTP::CookieMonster->new( $jar );

    my @cookies    = $monster->all_cookies;
    my $name_width = 10;

    my @methods = ( 'key', 'val', 'path', 'domain',
        'path_spec', 'secure', 'expires' );

    foreach my $cookie ( @cookies ) {

        my $t = Text::SimpleTable::AutoWidth->new();
        $t->captions( [ 'Key', 'Value' ] );

        foreach my $method ( @methods ) {
            my $val = $cookie->$method;
            if ( $val ) {
                $val = DateTime->from_epoch( epoch => $val )
                    if $method eq 'expires';
                $t->row( $method, $val );
            }
        }

        $self->logger->debug( ucfirst( $type ) . " Cookie:\n" . $t->draw );
    }

}

sub _get_content {
    my $self         = shift;
    my $ua           = shift;
    my $content_type = shift;

    my $content = $ua->decoded_content;
    return unless $content;

    if ( $self->content_pre_filter ) {
        $content = $self->content_pre_filter->( $content, $content_type );
    }
    return $content;
}

sub _log_content {
    my $self         = shift;
    my $ua           = shift;
    my $content_type = shift;

    return unless $self->dump_content;

    my $content = $self->_get_content( $ua, $content_type );

    return unless $content;

    my $t = Text::SimpleTable::AutoWidth->new();
    $t->captions( ['Content'] );

    $t->row( $content );
    $self->logger->debug( $t->draw );
}

sub _log_text {
    my $self         = shift;
    my $ua           = shift;
    my $content_type = shift;

    return unless $self->dump_text;
    my $content = $self->_get_content( $ua, $content_type );
    return unless $content;

    if ( $self->text_pre_filter ) {
        $content = $self->content_pre_filter->( $content, $content_type );
    }

    return unless $content;

    if ( $content_type =~ m{html}i ) {
        $content = $self->html_restrict->process( $content );
        $content =~ s{\s+}{ }g;
        $content =~ s{\n{2,}}{\n\n}g;
    }

    my $t = Text::SimpleTable::AutoWidth->new();
    $t->captions( ['Text'] );

    $t->row( $content );
    $self->logger->debug( $t->draw );
}

sub _build_term_width {
    my ( $self ) = @_;

    # cargo culted from Plack::Middleware::DebugLogging
    my $width = eval '
        my ($columns, $rows) = Term::Size::Any::chars;
        return $columns;
    ';

    if ( $@ ) {
        $width = $ENV{COLUMNS}
            if exists( $ENV{COLUMNS} )
            && $ENV{COLUMNS} =~ m/^\d+$/;
    }

    $width = 80 unless ( $width && $width >= 80 );
    return $width;
}

1;

# ABSTRACT: Easy LWP tracing and debugging

=pod

=head1 SYNOPSIS

    my $ua = LWP::UserAgent->new( cookie_jar => {} );
    my $logger = LWP::ConsoleLogger->new(
        dump_content       => 1,
        dump_text          => 1,
        content_pre_filter => sub {
            my $content      = shift;
            my $content_type = shift;

            # mangle content here
            ...

            return $content;
        },
    );

    my $ua = LWP::UserAgent->new();
    $ua->default_header(
        'Accept-Encoding' => scalar HTTP::Message::decodable() );

    $ua->add_handler( 'response_done',
        sub { $logger->response_callback( @_ ) } );
    $ua->add_handler( 'request_send',
        sub { $logger->request_callback( @_ ) } );

    # now watch debugging output to your screen
    $ua->get( $some_url );

    #################################################################

    # or start the easy way
    use LWP::ConsoleLogger::Easy qw( debug_ua );
    use WWW::Mechanize;

    my $mech = WWW::Mechanize->new; # or LWP::UserAgent->new() etc
    my $logger = debug_ua( $mech );
    $mech->get( $some_url );

    # now watch the console for debugging output
    # turn off header dumps
    $logger->dump_headers( 0 );

    $mech->get( $some_other_url );

    #################################################################
    # sample output might look like this

    GET http://www.nytimes.com/2014/04/24/technology/fcc-new-net-neutrality-rules.html

    Params:
    .-----+-------.
    | Key | Value |
    +-----+-------+
    | _r  | 1     |
    | hp  |       |
    '-----+-------'

    Request Headers:
    .-----------------+--------------------------------.
    | Header Name     | Value                          |
    +-----------------+--------------------------------+
    | Accept-Encoding | gzip                           |
    | Cookie2         | $Version="1"                   |
    | Referer         | http://www.nytimes.com?foo=bar |
    | User-Agent      | WWW-Mechanize/1.73             |
    '-----------------+--------------------------------'

    200 OK

    Title: The New York Times - Breaking News, World News & Multimedia

    Response Headers:
    .--------------------------+-------------------------------.
    | Header Name              | Value                         |
    +--------------------------+-------------------------------+
    | Accept-Ranges            | bytes                         |
    | Age                      | 176                           |
    | Cache-Control            | no-cache                      |
    | Channels                 | NytNow                        |
    | Client-Date              | Fri, 30 May 2014 22:37:42 GMT |
    | Client-Peer              | 170.149.172.130:80            |
    | Client-Response-Num      | 1                             |
    | Client-Transfer-Encoding | chunked                       |
    | Connection               | keep-alive                    |
    | Content-Encoding         | gzip                          |
    | Content-Type             | text/html; charset=utf-8      |
    | Date                     | Fri, 30 May 2014 22:37:41 GMT |
    | NtCoent-Length           | 65951                         |
    | Server                   | Apache                        |
    | Via                      | 1.1 varnish                   |
    | X-Cache                  | HIT                           |
    | X-Varnish                | 1142859770 1142854917         |
    '--------------------------+-------------------------------'

    .--------------------------+-------------------------------.
    | Text                                                     |
    +--------------------------+-------------------------------+
    | F.C.C., in a Shift, Backs Fast Lanes for Web Traffic...  |
    '--------------------------+-------------------------------'


=head1 DESCRIPTION

BETA BETA BETA.  This is currently an experiment.  Things could change.  Please
adjust accordingly.

It can be hard (or at least tedious) to debug mechanize scripts.  LWP::Debug is
deprecated.  It suggests you write your own debugging handlers, set up a proxy
or install Wireshark.  Those are all workable solutions, but this module exists
to save you some of that work.  The guts of this module are stolen from
L<Plack::Middleware::DebugLogging>, which in turn stole most of its internals
from L<Catalyst>.  If you're new to LWP::ConsoleLogger, I suggest getting
started with the L<LWP::ConsoleLogger::Easy> wrapper.  This will get you up and
running in minutes.  If you need to tweak the settings that
L<LWP::ConsoleLogger::Easy> chooses for you (or if you just want to be fancy),
please read on.

Since this is a debugging library, I've left as much mutable state as possible,
so that you can easily toggle output on and off and otherwise adjust how you
deal with the output.

=head1 CONSTRUCTOR

=head2 new()

The following arguments can be passed to new(), although none are required.
They can also be called as methods on an instantiated object.  I'll list them
here and discuss them in detail below.

=over 4

=item * C<< dump_content => 0|1 >>

=item * C<< dump_cookies => 0|1 >>

=item * C<< dump_headers => 0|1 >>

=item * C<< dump_params => 0|1 >>

=item * C<< dump_text => 0|1 >>

=item * C<< content_pre_filter => sub { ... } >>

=item * C<< text_pre_filter => sub { ... } >>

=item * C<< html_restrict => HTML::Restrict->new( ... ) >>

=item * C<< logger => Log::Dispatch->new( ... ) >>

=item * C<< term_width => $integer >>

=back

=head1 SUBROUTINES/METHODS

=head2 dump_content( 0|1 )

Boolean value. If true, the actual content of your response (HTML, JSON, etc)
will be dumped to your screen.  Defaults to false.

=head2 dump_cookies( 0|1 )

Boolean value. If true, the content of your cookies will be dumped to your
screen.  Defaults to false.

=head2 dump_headers( 0|1 )

Boolean value. If true, both request and response headers will be dumped to
your screen.  Defaults to true.

=head2 dump_params( 0|1 )

Boolean value. If true, both GET and POST params will be dumped to your screen.
Defaults to true.

=head2 dump_text( 0|1 )

Boolean value. If true, dumps the text of your page after both the
content_pre_filter and text_pre_filters have been applied.  Defaults to true.

=head2 content_pre_filter( sub { ... } )

Subroutine reference.  This allows you to manipulate content before it is
dumped.  A common use case might be stripping headers and footers away from
HTML content to make it easier to detect changes in the body of the page.

=head2 text_pre_filter( sub { ... } )

Subroutine reference.  This allows you to manipulate text before it is dumped.
A common use case might be stripping away duplicate whitespace and/or newlines
in order to improve formatting.

=head2 html_restrict( HTML::Restrict->new( ... ) )

If the content_type indicates HTML then HTML::Restrict will be used to strip
tags from your content in the text rendering process.  You may pass your own
HTML::Restrict object, if you like.  This would be helpful in situations where
you still do want to some some tags in your text.

=head2 logger( Log::Dispatch->new( ... ) )

By default all data will be dumped to your console (as the name of this module
implies) using Log::Dispatch.  However, you may use your own Log::Dispatch
module in order to facilitate logging to files or any other output which
Log::Dispatch supports.

=head2 term_width( $integer )

By default this module will try to find the maximum width of your terminal and
use all available space when displaying tabular data.  You may use this
parameter to constrain the tables to an arbitrary width.

=head1 CAVEATS

Aside from the BETA warnings, I should say that I've written this to suit my
needs and there are a lot of things I haven't considered.  For example, I'm
really only dealing with GET and POST.  There's probably a much better way of
getting the POST params than what I copied in a hurry from a very old module.
Also, I'm mostly assuming that the content will be text or HTML.

The test suite is not very robust either.  If you'd like to contribute to this
module and you can't find an appropriate test, do add something to the example
folder (either a new script or alter an existing one), so that I can see what
your patch does.

=cut
