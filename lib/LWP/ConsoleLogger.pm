use strict;
use warnings;

package LWP::ConsoleLogger;

use DDP;
use DateTime;
use HTML::Restrict;
use HTTP::CookieMonster;
use HTTP::Request;
use Log::Dispatch;
use Moo;
use Safe::Isa;
use Term::Size::Any qw( chars );
use Test::Most;
use Text::SimpleTable;
use Text::SimpleTable::AutoWidth;
use URI::QueryParam;

sub BUILD {
    my $self = shift;
    $Text::SimpleTable::AutoWidth::WIDTH_LIMIT = $self->term_width();
}

has content_regex => ( is => 'rw', );

has dump_cookies => (
    is      => 'rw',
    default => sub {0},
);

has dump_content => (
    is      => 'rw',
    default => sub {0},
);

has dump_text => (
    is      => 'rw',
    default => sub {0},
);

has logger => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        return Log::Dispatch->new(
            outputs => [ [ 'Screen', min_level => 'debug', newline => 1, ], ],
        );
    },
);

has term_width => (
    is       => 'ro',
    required => 0,
    lazy => 1,
    builder => '_build_term_width',
);

sub request_callback {
    my $self = shift;
    my $req  = shift;
    my $ua   = shift;

    my $uri_without_query = $req->uri->clone;
    $uri_without_query->query( undef );
    $self->logger->debug( $req->method . q{ } . $uri_without_query . "\n" );
    $self->_log_params( $req->uri );

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

    $self->_log_text( $res );
    return;
}

sub _log_headers {
    my ( $self, $type, $headers ) = @_;

    my $t = Text::SimpleTable::AutoWidth->new();
    $t->captions( [ 'Header Name', 'Value' ] );

    foreach my $name ( sort $headers->header_field_names ) {
        next if $name eq 'Cookie' || $name eq 'Set-Cookie';
        $t->row( $name, $headers->header( $name ) );
    }

    $self->logger->debug( ucfirst( $type ) . " Headers:\n" . $t->draw );
}

sub _log_params {
    my ( $self, $uri ) = @_;

    my $name_width = 1;
    my @params     = sort $uri->query_param;
    return unless @params;

    my $t = Text::SimpleTable::AutoWidth->new();
    $t->captions( [ 'Key', 'Value' ] );
    foreach my $name ( @params ) {
        my @values = $uri->query_param( $name );
        $t->row( $name, $_ ) for sort @values;
    }

    $self->logger->debug( " Params:\n" . $t->draw );
}

sub _log_cookies {
    my $self = shift;
    return unless $self->dump_cookies;

    my $type = shift;
    my $jar  = shift;

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

sub _log_text {
    my $self = shift;
    my $ua   = shift;

    return unless $self->dump_text;
    my $content = $ua->decoded_content;
    return unless $content;

    my $title = 'Text';

    if (   $self->content_regex
        && $content =~ $self->content_regex )
    {
        $content = $1;
        $title   = 'Wrapped Text';
    }

    my $hr = HTML::Restrict->new;
    $content = $hr->process( $content );
    $content =~ s{\s+}{ }g;
    $content =~ s{\n{2,}}{\n\n}g;
    my $t = Text::SimpleTable::AutoWidth->new();
    $t->captions( ['Wrapped Text'] );

    $t->row( $hr->process( $content ) );
    $self->logger->debug( $t->draw );
}

sub _build_term_width {
    my ( $self ) = @_;

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
