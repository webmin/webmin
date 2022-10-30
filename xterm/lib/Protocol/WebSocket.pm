package Protocol::WebSocket;

use strict;
use warnings;

our $VERSION = '0.26';

use Protocol::WebSocket::Frame;
use Protocol::WebSocket::Handshake::Client;
use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::URL;

1;
__END__

=encoding UTF-8

=head1 NAME

Protocol::WebSocket - WebSocket protocol

=head1 SYNOPSIS

    # Server side
    my $hs = Protocol::WebSocket::Handshake::Server->new;

    $hs->parse('some data from the client');

    $hs->is_done; # tells us when handshake is done

    my $frame = $hs->build_frame;

    $frame->append('some data from the client');

    while (defined(my $message = $frame->next)) {
        if ($frame->is_close) {

            # Send close frame back
            send(
                $hs->build_frame(
                    type    => 'close',
                    version => $version
                )->to_bytes
            );

            return;
        }

        # We got a message!
    }

=head1 DESCRIPTION

Client/server WebSocket message and frame parser/constructor. This module does
not provide a WebSocket server or client, but is made for using in http servers
or clients to provide WebSocket support.

L<Protocol::WebSocket> supports the following WebSocket protocol versions:

    draft-ietf-hybi-17 (latest)
    draft-ietf-hybi-10
    draft-ietf-hybi-00 (with HAProxy support)
    draft-hixie-75

By default the latest version is used. The WebSocket version is detected
automatically on the server side. On the client side you have set a C<version>
attribute to an appropriate value.

L<Protocol::WebSocket> itself does not contain any code and cannot be used
directly. Instead the following modules should be used:

=head2 High-level modules

=head3 L<Protocol::WebSocket::Server>

Server helper class.

=head3 L<Protocol::WebSocket::Client>

Client helper class.

=head2 Low-level modules

=head3 L<Protocol::WebSocket::Handshake::Server>

Server handshake parser and constructor.

=head3 L<Protocol::WebSocket::Handshake::Client>

Client handshake parser and constructor.

=head3 L<Protocol::WebSocket::Frame>

WebSocket frame parser and constructor.

=head3 L<Protocol::WebSocket::Request>

Low level WebSocket request parser and constructor.

=head3 L<Protocol::WebSocket::Response>

Low level WebSocket response parser and constructor.

=head3 L<Protocol::WebSocket::URL>

Low level WebSocket url parser and constructor.

=head1 EXAMPLES

For examples on how to use L<Protocol::WebSocket> with various event loops see
C<examples/> directory in the distribution.

=head1 CREDITS

In order of appearance:

Paul "LeoNerd" Evans

Jon Gentle

Lee Aylward

Chia-liang Kao

Atomer Ju

Chuck Bredestege

Matthew Lien (BlueT)

Joao Orui

Toshio Ito (debug-ito)

Neil Bowers

Michal Špaček

Graham Ollis

Anton Petrusevich

Eric Wastl

=head1 AUTHOR

Viacheslav Tykhanovskyi, C<vti@cpan.org>.

=head1 COPYRIGHT

Copyright (C) 2010-2018, Viacheslav Tykhanovskyi.

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl 5.10.

=cut
