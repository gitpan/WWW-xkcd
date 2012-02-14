use strict;
use warnings;
package WWW::xkcd;
{
  $WWW::xkcd::VERSION = '0.003';
}
# ABSTRACT: Synchronous and asynchronous interfaces to xkcd comics

use Carp;
use JSON;
use Try::Tiny;
use HTTP::Tiny;

sub new {
    my $class = shift;
    my %args  = (
        baseurl  => 'http://xkcd.com',
        infopath => 'info.0.json',
        @_,
    );

    return bless { %args }, $class;
}

sub fetch_metadata {
    my $self           = shift;
    my $base           = $self->{'baseurl'};
    my $path           = $self->{'infopath'};
    my ( $comic, $cb ) = $self->_parse_args(@_);

    my $url = defined $comic ? "$base/$comic/$path" : "$base/$path";

    if ($cb) {
        # this is async
        eval "use AnyEvent";
        $@ and croak 'AnyEvent is required for async mode';

        eval 'use AnyEvent::HTTP';
        $@ and croak 'AnyEvent::HTTP is required for async mode';

        AnyEvent::HTTP::http_get( $url, sub {
            my $body = shift;
            my $meta = $self->_decode_json($body);

            return $cb->($meta);
        } );

        return 0;
    } else {
        # this is sync
        my $result = HTTP::Tiny->new->get($url);

        $result->{'success'} or croak "Can't fetch $url: " .
            $result->{'reason'};

        my $meta = $self->_decode_json( $result->{'content'} );

        return $meta;
    }

    return 1;
}

sub fetch {
    my $self           = shift;
    my $base           = $self->{'baseurl'};
    my $path           = $self->{'infopath'};
    my ( $comic, $cb ) = $self->_parse_args(@_);

    if ($cb) {
        $self->fetch_metadata( $comic, sub {
            my $meta = shift;
            my $img  = $meta->{'img'};

            AnyEvent::HTTP::http_get( $img, sub {
                my $img_data = shift;

                # call original callback
                return $cb->( $img_data, $meta );
            } );
        } );

        return 0;
    }

    my $meta = $self->fetch_metadata($comic);
    my $img  = $meta->{'img'};

    # FIXME: this is copied and should be refactored
    my $result = HTTP::Tiny->new->get($img);

    $result->{'success'} or croak "Can't fetch $img: " .
        $result->{'reason'};

    return ( $result->{'content'}, $meta );
}

sub _parse_args {
    my $self = shift;
    my @args = @_;
    my ( $comic, $cb );

    # @_ = $num, $cb
    # @_ = $num
    # @_ = $cb
    if ( @_ == 2 ) {
        ( $comic, $cb ) = @_;
    } elsif ( @_ == 1 ) {
        if ( ref $_[0] ) {
            $cb = $_[0];
        } else {
            $comic = $_[0];
        }
    }

    return ( $comic, $cb );
}

sub _decode_json {
    my $self = shift;
    my $json = shift;
    my $data = try   { decode_json $json                }
               catch { croak "Can't decode '$json': $_" };

    return $data;
}

1;



=pod

=head1 NAME

WWW::xkcd - Synchronous and asynchronous interfaces to xkcd comics

=head1 VERSION

version 0.003

=head1 SYNOPSIS

    use WWW::xkcd;
    my $xkcd  = WWW::xkcd->new;
    my ( $img, $comic ) = $xkcd->fetch; # provides latest comic
    say "Today's comic is titled: ", $comic->{'title'};

    # and now to write it to file
    use IO::All;
    use File::Basename;
    $img > io( basename $comic->{'img'} );

    # or in async mode
    $xkcd->fetch( sub {
        my ( $img, $comic ) = @_;
        say "Today's comic is titled: ", $comic->{'title'};

        ...
    } );

=head1 DESCRIPTION

This module allows you to access xkcd comics (http://www.xkcd.com/) using
the official API in synchronous mode (what people are used to) or in
asynchronous mode.

The asynchronous mode requires you have L<AnyEvent> and L<AnyEvent::HTTP>
available. However, since it's just I<supported> and not I<necessary>, it is not
declared as a prerequisite.

=head1 METHODS

=head2 new

Create a new L<WWW::xkcd> object.

    # typical usage
    my $xkcd = WWW::xkcd->new;

    # it would be pointless to change these, but it's possible
    my $xkcd = WWW::xkcd->new(
        base_url => 'http://www.xkcd.com',
        infopath => 'info.0.json',
    );

=head2 fetch

Fetch both the metadata and image of a comic.

    # fetching the latest
    my ( $comic, $meta ) = $xkcd->fetch;

    # fetching a specific one
    my ( $comic, $meta ) = $xkcd->fetch(20);

    # using callbacks for async mode
    $xkcd->fetch( sub { my ( $comic, $meta ) = @_; ... } );

    # using callbacks for a specific one
    $xkcd->fetch( 20, sub { my ( $comic, $meta ) = @_; ... } );

This runs two requests: one to get the metadata using the API and the second
to get the image itself. If you don't need the image, it would be better (and
faster) for you to use the C<fetch_metadata> method below.

=head2 fetch_metadata

Fetch just the metadata of the comic.

    my $meta = $xkcd->fetch_metadata;

    # using callbacks for async mode
    $xkcd->fetch_metadata( sub { my $meta = shift; ... } );

=head1 NAMING

Why would you call it WWW::I<xkcd> with all lower cases? Simply because that's
what Randall Munroe who writes xkcd prefers.

Taken verbatim from L<http://www.xkcd.com/about>:

    How do I write "xkcd"? There's nothing in Strunk and White about this.

    For those of us pedantic enough to want a rule, here it is: The preferred
    form is "xkcd", all lower-case. In formal contexts where a lowercase word
    shouldn't start a sentence, "XKCD" is an okay alternative. "Xkcd" is
    frowned upon.

=head1 DEPENDENCIES

=over 4

=item * Try::Tiny

=item * HTTP::Tiny

=item * JSON

=item * Carp

=back

=head1 OPTIONAL DEPENDENCIES

=over 4

=item * AnyEvent

=item * AnyEvent::HTTP

=back

=head1 AUTHOR

Sawyer X <xsawyerx@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Sawyer X.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__END__

