# INTERNAL MODULE: guts for StrMatch type from Types::Standard.

package Types::Standard::StrMatch;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Types::Standard::StrMatch::AUTHORITY = 'cpan:TOBYINK';
	$Types::Standard::StrMatch::VERSION   = '2.000001';
}

$Types::Standard::StrMatch::VERSION =~ tr/_//d;

use Type::Tiny      ();
use Types::Standard ();
use Types::TypeTiny ();

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

no warnings;

our %expressions;
my $has_regexp_util;
my $serialize_regexp = sub {
	$has_regexp_util = eval {
		require Regexp::Util;
		Regexp::Util->VERSION( '0.003' );
		1;
	} || 0 unless defined $has_regexp_util;
	
	my $re = shift;
	my $serialized;
	if ( $has_regexp_util ) {
		$serialized = eval { Regexp::Util::serialize_regexp( $re ) };
	}
	
	unless ( defined $serialized ) {
		my $key = sprintf( '%s|%s', ref( $re ), $re );
		$expressions{$key} = $re;
		$serialized = sprintf(
			'$Types::Standard::StrMatch::expressions{%s}',
			B::perlstring( $key )
		);
	}
	
	return $serialized;
};

sub __constraint_generator {
	return Types::Standard->meta->get_type( 'StrMatch' ) unless @_;
	
	my ( $regexp, $checker ) = @_;
	
	Types::Standard::is_RegexpRef( $regexp )
		or _croak(
		"First parameter to StrMatch[`a] expected to be a Regexp; got $regexp" );
		
	if ( @_ > 1 ) {
		$checker = Types::TypeTiny::to_TypeTiny( $checker );
		Types::TypeTiny::is_TypeTiny( $checker )
			or _croak(
			"Second parameter to StrMatch[`a] expected to be a type constraint; got $checker"
			);
	}
	
	$checker
		? sub {
		my $value = shift;
		return if ref( $value );
		my @m = ( $value =~ $regexp );
		$checker->check( \@m );
		}
		: sub {
		my $value = shift;
		!ref( $value ) and $value =~ $regexp;
		};
} #/ sub __constraint_generator

sub __inline_generator {
	require B;
	my ( $regexp, $checker ) = @_;
	my $serialized_re = $regexp->$serialize_regexp or return;
	
	if ( $checker ) {
		return unless $checker->can_be_inlined;
		
		return sub {
			my $v = $_[1];
			if ( $Type::Tiny::AvoidCallbacks
				and $serialized_re =~ /Types::Standard::StrMatch::expressions/ )
			{
				require Carp;
				Carp::carp(
					"Cannot serialize regexp without callbacks; serializing using callbacks" );
			}
			sprintf
				"!ref($v) and do { my \$m = [$v =~ %s]; %s }",
				$serialized_re,
				$checker->inline_check( '$m' ),
				;
		};
	} #/ if ( $checker )
	else {
		my $regexp_string = "$regexp";
		if ( $regexp_string =~ /\A\(\?\^u?:\\A(\.+)\)\z/ ) {
			my $length = length $1;
			return sub { "!ref($_) and length($_)>=$length" };
		}
		
		if ( $regexp_string =~ /\A\(\?\^u?:\\A(\.+)\\z\)\z/ ) {
			my $length = length $1;
			return sub { "!ref($_) and length($_)==$length" };
		}
		
		return sub {
			my $v = $_[1];
			if ( $Type::Tiny::AvoidCallbacks
				and $serialized_re =~ /Types::Standard::StrMatch::expressions/ )
			{
				require Carp;
				Carp::carp(
					"Cannot serialize regexp without callbacks; serializing using callbacks" );
			}
			"!ref($v) and $v =~ $serialized_re";
		};
	} #/ else [ if ( $checker ) ]
} #/ sub __inline_generator

1;
