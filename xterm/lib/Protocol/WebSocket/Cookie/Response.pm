package Protocol::WebSocket::Cookie::Response;

use strict;
use warnings;

use base 'Protocol::WebSocket::Cookie';

sub parse {
    my $self = shift;

    $self->SUPER::parse(@_);
}

sub to_string {
    my $self = shift;

    my $pairs = [];

    push @$pairs, [$self->{name}, $self->{value}];

    push @$pairs, ['Comment', $self->{comment}] if defined $self->{comment};

    push @$pairs, ['CommentURL', $self->{comment_url}]
      if defined $self->{comment_url};

    push @$pairs, ['Discard'] if $self->{discard};

    push @$pairs, ['Max-Age' => $self->{max_age}] if defined $self->{max_age};

    push @$pairs, ['Path'    => $self->{path}]    if defined $self->{path};

    if (defined $self->{portlist}) {
        $self->{portlist} = [$self->{portlist}]
          unless ref $self->{portlist} eq 'ARRAY';
        my $list = join ' ' => @{$self->{portlist}};
        push @$pairs, ['Port' => "\"$list\""];
    }

    push @$pairs, ['Secure'] if $self->{secure};

    push @$pairs, ['Version' => '1'];

    $self->pairs($pairs);

    return $self->SUPER::to_string;
}

1;
__END__

=head1 NAME

Protocol::WebSocket::Cookie::Response - WebSocket Cookie Response

=head1 SYNOPSIS

    # Constructor
    my $cookie = Protocol::WebSocket::Cookie::Response->new(
        name    => 'foo',
        value   => 'bar',
        discard => 1,
        max_age => 0
    );
    $cookie->to_string; # foo=bar; Discard; Max-Age=0; Version=1

    # Parser
    my $cookie = Protocol::WebSocket::Cookie::Response->new;
    $cookie->parse('foo=bar; Discard; Max-Age=0; Version=1');

=head1 DESCRIPTION

Construct or parse a WebSocket response cookie.

=head1 METHODS

=head2 C<parse>

Parse a WebSocket response cookie.

=head2 C<to_string>

Construct a WebSocket response cookie.

=cut
