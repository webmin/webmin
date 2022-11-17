# INTERNAL MODULE: guts for Tied type from Types::Standard.

package Types::Standard::Tied;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Types::Standard::Tied::AUTHORITY = 'cpan:TOBYINK';
	$Types::Standard::Tied::VERSION   = '2.000001';
}

$Types::Standard::Tied::VERSION =~ tr/_//d;

use Type::Tiny      ();
use Types::Standard ();
use Types::TypeTiny ();

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

no warnings;

sub __constraint_generator {
	return Types::Standard->meta->get_type( 'Tied' ) unless @_;
	
	my $param = Types::TypeTiny::to_TypeTiny( shift );
	unless ( Types::TypeTiny::is_TypeTiny( $param ) ) {
		Types::TypeTiny::is_StringLike( $param )
			or _croak( "Parameter to Tied[`a] expected to be a class name; got $param" );
		require Type::Tiny::Class;
		$param = "Type::Tiny::Class"->new( class => "$param" );
	}
	
	my $check = $param->compiled_check;
	sub {
		$check->(
			tied(
				Scalar::Util::reftype( $_ ) eq 'HASH'             ? %{$_}
				: Scalar::Util::reftype( $_ ) eq 'ARRAY'          ? @{$_}
				: Scalar::Util::reftype( $_ ) =~ /^(SCALAR|REF)$/ ? ${$_}
				:                                                   undef
			)
		);
	};
} #/ sub __constraint_generator

sub __inline_generator {
	my $param = Types::TypeTiny::to_TypeTiny( shift );
	unless ( Types::TypeTiny::is_TypeTiny( $param ) ) {
		Types::TypeTiny::is_StringLike( $param )
			or _croak( "Parameter to Tied[`a] expected to be a class name; got $param" );
		require Type::Tiny::Class;
		$param = "Type::Tiny::Class"->new( class => "$param" );
	}
	return unless $param->can_be_inlined;
	
	sub {
		require B;
		my $var = $_[1];
		sprintf(
			"%s and do { my \$TIED = tied(Scalar::Util::reftype($var) eq 'HASH' ? \%{$var} : Scalar::Util::reftype($var) eq 'ARRAY' ? \@{$var} : Scalar::Util::reftype($var) =~ /^(SCALAR|REF)\$/ ? \${$var} : undef); %s }",
			Types::Standard::Ref()->inline_check( $var ),
			$param->inline_check( '$TIED' )
		);
	}
} #/ sub __inline_generator

1;
