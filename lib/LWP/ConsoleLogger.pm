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
    $Text::SimpleTable::AutoWidth::WIDTH_LIMIT = $self->_term_width();
}

has dump_cookies => (
    is      => 'rw',
    default => sub {0},
);

has dump_text => (
    is      => 'rw',
    default => sub {0},
);

has dump_content => (
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

has content_regex => ( is => 'rw', );

has term_width => (
    is       => 'ro',
    required => 0,
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

    my $name_width = 15;
    foreach my $name ( $headers->header_field_names ) {
        $name_width = length( $name ) if length( $name ) > $name_width;
    }

    my $t = Text::SimpleTable->new( [ $name_width, 'Header Name' ],
        [ $self->_term_width - $name_width, 'Value' ] );
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

    foreach my $name ( @params ) {
        $name_width = length( $name ) if length( $name ) > $name_width;
    }

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

        my $t = Text::SimpleTable->new( [ $name_width, 'Key' ],
            [ $self->_term_width - $name_width, 'Value' ] );
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
    my $table = $self->_table;
    $table = Text::SimpleTable::AutoWidth->new();
    $table->captions( ['Wrapped Text'] );

    $table->row( $hr->process( $content ) );
    $self->logger->debug( $table->draw );
}

sub _term_width {
    my ( $self ) = @_;

    return $self->term_width if $self->term_width;

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

sub _table {
    my $self = shift;
    return Text::SimpleTable::AutoWidth->new( $self->term_width || $self->_term_width );
}

1;

# ABSTRACT: Easy LWP tracing and debugging
