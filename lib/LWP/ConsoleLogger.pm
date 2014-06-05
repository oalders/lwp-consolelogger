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

=cut
