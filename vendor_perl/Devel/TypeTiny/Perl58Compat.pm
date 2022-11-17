# INTERNAL MODULE: Perl 5.8 compatibility for Type::Tiny.

package Devel::TypeTiny::Perl58Compat;

use 5.008;
use strict;
use warnings;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '2.000001';

$VERSION =~ tr/_//d;

#### re doesn't provide is_regexp in Perl < 5.10

eval 'require re';

unless ( exists &re::is_regexp ) {
	require B;
	*re::is_regexp = sub {
		eval { B::svref_2object( $_[0] )->MAGIC->TYPE eq 'r' };
	};
}

#### Done!

5.8;
