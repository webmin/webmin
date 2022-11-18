package Type::Parser;

use 5.008001;
use strict;
use warnings;

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '2.000001';

$VERSION =~ tr/_//d;

# Token types
#
sub TYPE ()      { "TYPE" }
sub QUOTELIKE () { "QUOTELIKE" }
sub STRING ()    { "STRING" }
sub HEXNUM ()    { "HEXNUM" }
sub CLASS ()     { "CLASS" }
sub L_BRACKET () { "L_BRACKET" }
sub R_BRACKET () { "R_BRACKET" }
sub COMMA ()     { "COMMA" }
sub SLURPY ()    { "SLURPY" }
sub UNION ()     { "UNION" }
sub INTERSECT () { "INTERSECT" }
sub SLASH ()     { "SLASH" }
sub NOT ()       { "NOT" }
sub L_PAREN ()   { "L_PAREN" }
sub R_PAREN ()   { "R_PAREN" }
sub MYSTERY ()   { "MYSTERY" }

our @EXPORT_OK = qw( eval_type _std_eval parse extract_type );

require Exporter::Tiny;
our @ISA = 'Exporter::Tiny';

Evaluate: {

	sub parse {
		my $str    = $_[0];
		my $parser = "Type::Parser::AstBuilder"->new( input => $str );
		$parser->build;
		wantarray ? ( $parser->ast, $parser->remainder ) : $parser->ast;
	}
	
	sub extract_type {
		my ( $str,    $reg )  = @_;
		my ( $parsed, $tail ) = parse( $str );
		wantarray
			? ( _eval_type( $parsed, $reg ), $tail )
			: _eval_type( $parsed, $reg );
	}
	
	sub eval_type {
		my ( $str,    $reg )  = @_;
		my ( $parsed, $tail ) = parse( $str );
		_croak( "Unexpected tail on type expression: $tail" ) if $tail =~ /\S/sm;
		return _eval_type( $parsed, $reg );
	}
	
	my $std;
	
	sub _std_eval {
		require Type::Registry;
		unless ( $std ) {
			$std = "Type::Registry"->new;
			$std->add_types( -Standard );
		}
		eval_type( $_[0], $std );
	}
	
	sub _eval_type {
		my ( $node, $reg ) = @_;
		
		$node = _simplify_expression( $node );
		
		if ( $node->{type} eq "list" ) {
			return map _eval_type( $_, $reg ), @{ $node->{list} };
		}
		
		if ( $node->{type} eq "union" ) {
			return $reg->_make_union_by_overload( map _eval_type( $_, $reg ), @{ $node->{union} } );
		}
		
		if ( $node->{type} eq "intersect" ) {
			return $reg->_make_intersection_by_overload(
				map _eval_type( $_, $reg ),
				@{ $node->{intersect} }
			);
		}
		
		if ( $node->{type} eq "slash" ) {
			my @types = map _eval_type( $_, $reg ), @{ $node->{slash} };
			_croak( "Expected exactly two types joined with slash operator" )
				unless @types == 2;
			return $types[0] / $types[1];
		}
		
		if ( $node->{type} eq "slurpy" ) {
			require Types::Standard;
			return Types::Standard::Slurpy()->of( _eval_type( $node->{of}, $reg ) );
		}
		
		if ( $node->{type} eq "complement" ) {
			return _eval_type( $node->{of}, $reg )->complementary_type;
		}
		
		if ( $node->{type} eq "parameterized" ) {
			my $base = _eval_type( $node->{base}, $reg );
			
			return $base unless $base->is_parameterizable || $node->{params};
			return $base->parameterize(
				$node->{params} ? _eval_type( $node->{params}, $reg ) : () );
		}
		
		if ( $node->{type} eq "primary" and $node->{token}->type eq CLASS ) {
			my $class = substr(
				$node->{token}->spelling,
				0,
				length( $node->{token}->spelling ) - 2
			);
			return $reg->make_class_type( $class );
		}
		
		if ( $node->{type} eq "primary" and $node->{token}->type eq QUOTELIKE ) {
			return eval( $node->{token}->spelling );    #ARGH
		}
		
		if ( $node->{type} eq "primary" and $node->{token}->type eq STRING ) {
			return $node->{token}->spelling;
		}
		
		if ( $node->{type} eq "primary" and $node->{token}->type eq HEXNUM ) {
			my $sign = '+';
			my $spelling = $node->{token}->spelling;
			if ( $spelling =~ /^[+-]/ ) {
				$sign = substr( $spelling, 0, 1);
				$spelling = substr( $spelling, 1 );
			}
			return (
				( $sign eq '-' ) ? ( 0 - hex($spelling) ) : hex($spelling)
			);
		}
		
		if ( $node->{type} eq "primary" and $node->{token}->type eq TYPE ) {
			my $t = $node->{token}->spelling;
			my $r =
				( $t =~ /^(.+)::(\w+)$/ )
				? $reg->foreign_lookup( $t, 1 )
				: $reg->simple_lookup( $t, 1 );
			$r or _croak( "%s is not a known type constraint", $node->{token}->spelling );
			return $r;
		}
	} #/ sub _eval_type
	
	sub _simplify_expression {
		my $expr = shift;
		
		if ( $expr->{type} eq "expression" and $expr->{op}[0] eq COMMA ) {
			return _simplify( "list", COMMA, $expr );
		}
		
		if ( $expr->{type} eq "expression" and $expr->{op}[0] eq UNION ) {
			return _simplify( "union", UNION, $expr );
		}
		
		if ( $expr->{type} eq "expression" and $expr->{op}[0] eq INTERSECT ) {
			return _simplify( "intersect", INTERSECT, $expr );
		}
		
		if ( $expr->{type} eq "expression" and $expr->{op}[0] eq SLASH ) {
			return _simplify( "slash", SLASH, $expr );
		}
		
		return $expr;
	} #/ sub _simplify_expression
	
	sub _simplify {
		no warnings 'recursion';
		my $type = shift;
		my $op   = shift;
		
		my @list;
		for my $expr ( $_[0]{lhs}, $_[0]{rhs} ) {
			if ( $expr->{type} eq "expression" and $expr->{op}[0] eq $op ) {
				my $simple = _simplify( $type, $op, $expr );
				push @list, @{ $simple->{$type} };
			}
			else {
				push @list, $expr;
			}
		}
		
		return { type => $type, $type => \@list };
	} #/ sub _simplify
} #/ Evaluate:

{
	package Type::Parser::AstBuilder;
	
	our $AUTHORITY = 'cpan:TOBYINK';
	our $VERSION   = '2.000001';
	
	$VERSION =~ tr/_//d;
	
	sub new {
		my $class = shift;
		bless {@_}, $class;
	}
	
	our %precedence = (
	
		#		Type::Parser::COMMA()     , 1 ,
		Type::Parser::SLASH(),     1,
		Type::Parser::UNION(),     2,
		Type::Parser::INTERSECT(), 3,
		Type::Parser::NOT(),       4,
	);
	
	sub _parse_primary {
		my $self   = shift;
		my $tokens = $self->{tokens};
		
		$tokens->assert_not_empty;
		
		if ( $tokens->peek( 0 )->type eq Type::Parser::NOT ) {
			$tokens->eat( Type::Parser::NOT );
			$tokens->assert_not_empty;
			return {
				type => "complement",
				of   => $self->_parse_primary,
			};
		}
		
		if ( $tokens->peek( 0 )->type eq Type::Parser::SLURPY ) {
			$tokens->eat( Type::Parser::SLURPY );
			$tokens->assert_not_empty;
			return {
				type => "slurpy",
				of   => $self->_parse_primary,
			};
		}
		
		if ( $tokens->peek( 0 )->type eq Type::Parser::L_PAREN ) {
			$tokens->eat( Type::Parser::L_PAREN );
			my $r = $self->_parse_expression;
			$tokens->eat( Type::Parser::R_PAREN );
			return $r;
		}
		
		if ( $tokens->peek( 1 )
			and $tokens->peek( 0 )->type eq Type::Parser::TYPE
			and $tokens->peek( 1 )->type eq Type::Parser::L_BRACKET )
		{
			my $base = { type => "primary", token => $tokens->eat( Type::Parser::TYPE ) };
			$tokens->eat( Type::Parser::L_BRACKET );
			$tokens->assert_not_empty;
			
			local $precedence{ Type::Parser::COMMA() } = 1;
			
			my $params = undef;
			if ( $tokens->peek( 0 )->type eq Type::Parser::R_BRACKET ) {
				$tokens->eat( Type::Parser::R_BRACKET );
			}
			else {
				$params = $self->_parse_expression;
				$params = { type => "list", list => [$params] }
					unless $params->{type} eq "list";
				$tokens->eat( Type::Parser::R_BRACKET );
			}
			return {
				type   => "parameterized",
				base   => $base,
				params => $params,
			};
		} #/ if ( $tokens->peek( 1 ...))
		
		my $type = $tokens->peek( 0 )->type;
		if ( $type eq Type::Parser::TYPE
			or $type eq Type::Parser::QUOTELIKE
			or $type eq Type::Parser::STRING
			or $type eq Type::Parser::HEXNUM
			or $type eq Type::Parser::CLASS )
		{
			return { type => "primary", token => $tokens->eat };
		}
		
		Type::Parser::_croak(
			"Unexpected token in primary type expression; got '%s'",
			$tokens->peek( 0 )->spelling
		);
	} #/ sub _parse_primary
	
	sub _parse_expression_1 {
		my $self   = shift;
		my $tokens = $self->{tokens};
		
		my ( $lhs, $min_p ) = @_;
		while ( !$tokens->empty
			and defined( $precedence{ $tokens->peek( 0 )->type } )
			and $precedence{ $tokens->peek( 0 )->type } >= $min_p )
		{
			my $op  = $tokens->eat;
			my $rhs = $self->_parse_primary;
			
			while ( !$tokens->empty
				and defined( $precedence{ $tokens->peek( 0 )->type } )
				and $precedence{ $tokens->peek( 0 )->type } > $precedence{ $op->type } )
			{
				my $lookahead = $tokens->peek( 0 );
				$rhs = $self->_parse_expression_1( $rhs, $precedence{ $lookahead->type } );
			}
			
			$lhs = {
				type => "expression",
				op   => $op,
				lhs  => $lhs,
				rhs  => $rhs,
			};
		} #/ while ( !$tokens->empty and...)
		return $lhs;
	} #/ sub _parse_expression_1
	
	sub _parse_expression {
		my $self   = shift;
		my $tokens = $self->{tokens};
		
		return $self->_parse_expression_1( $self->_parse_primary, 0 );
	}
	
	sub build {
		my $self = shift;
		$self->{tokens} =
			"Type::Parser::TokenStream"->new( remaining => $self->{input} );
		$self->{ast} = $self->_parse_expression;
	}
	
	sub ast {
		$_[0]{ast};
	}
	
	sub remainder {
		$_[0]{tokens}->remainder;
	}
}

{
	package Type::Parser::Token;
	
	our $AUTHORITY = 'cpan:TOBYINK';
	our $VERSION   = '2.000001';
	
	$VERSION =~ tr/_//d;
	
	sub type     { $_[0][0] }
	sub spelling { $_[0][1] }
}

{
	package Type::Parser::TokenStream;
	
	our $AUTHORITY = 'cpan:TOBYINK';
	our $VERSION   = '2.000001';
	
	$VERSION =~ tr/_//d;
	
	use Scalar::Util qw(looks_like_number);
	
	sub new {
		my $class = shift;
		bless { stack => [], done => [], @_ }, $class;
	}
	
	sub peek {
		my $self  = shift;
		my $ahead = $_[0];
		
		while ( $self->_stack_size <= $ahead and length $self->{remaining} ) {
			$self->_stack_extend;
		}
		
		my @tokens = grep ref, @{ $self->{stack} };
		return $tokens[$ahead];
	} #/ sub peek
	
	sub empty {
		my $self = shift;
		not $self->peek( 0 );
	}
	
	sub eat {
		my $self = shift;
		$self->_stack_extend unless $self->_stack_size;
		my $r;
		while ( defined( my $item = shift @{ $self->{stack} } ) ) {
			push @{ $self->{done} }, $item;
			if ( ref $item ) {
				$r = $item;
				last;
			}
		}
		
		if ( @_ and $_[0] ne $r->type ) {
			unshift @{ $self->{stack} }, pop @{ $self->{done} };          # uncoverable statement
			Type::Parser::_croak( "Expected $_[0]; got " . $r->type );    # uncoverable statement
		}
		
		return $r;
	} #/ sub eat
	
	sub assert_not_empty {
		my $self = shift;
		Type::Parser::_croak( "Expected token; got empty string" ) if $self->empty;
	}
	
	sub _stack_size {
		my $self = shift;
		scalar grep ref, @{ $self->{stack} };
	}
	
	sub _stack_extend {
		my $self = shift;
		push @{ $self->{stack} }, $self->_read_token;
		my ( $space ) = ( $self->{remaining} =~ m/^([\s\n\r]*)/sm );
		return unless length $space;
		push @{ $self->{stack} }, $space;
		substr( $self->{remaining}, 0, length $space ) = "";
	}
	
	sub remainder {
		my $self = shift;
		return join "",
			map { ref( $_ ) ? $_->spelling : $_ }
			( @{ $self->{stack} }, $self->{remaining} );
	}
	
	my %punctuation = (
		'['      => bless( [ Type::Parser::L_BRACKET, "[" ],   "Type::Parser::Token" ),
		']'      => bless( [ Type::Parser::R_BRACKET, "]" ],   "Type::Parser::Token" ),
		'('      => bless( [ Type::Parser::L_PAREN,   "[" ],   "Type::Parser::Token" ),
		')'      => bless( [ Type::Parser::R_PAREN,   "]" ],   "Type::Parser::Token" ),
		','      => bless( [ Type::Parser::COMMA,     "," ],   "Type::Parser::Token" ),
		'=>'     => bless( [ Type::Parser::COMMA,     "=>" ],  "Type::Parser::Token" ),
		'slurpy' => bless( [ Type::Parser::SLURPY, "slurpy" ], "Type::Parser::Token" ),
		'|'      => bless( [ Type::Parser::UNION,     "|" ],   "Type::Parser::Token" ),
		'&'      => bless( [ Type::Parser::INTERSECT, "&" ],   "Type::Parser::Token" ),
		'/'      => bless( [ Type::Parser::SLASH,     "/" ],   "Type::Parser::Token" ),
		'~'      => bless( [ Type::Parser::NOT,       "~" ],   "Type::Parser::Token" ),
	);
	
	sub _read_token {
		my $self = shift;
		
		return if $self->{remaining} eq "";
		
		# Punctuation
		#
		
		if ( $self->{remaining} =~ /^( => | [()\]\[|&~,\/] )/xsm ) {
			my $spelling = $1;
			substr( $self->{remaining}, 0, length $spelling ) = "";
			return $punctuation{$spelling};
		}
		
		if ( $self->{remaining} =~ /\A\s*[q'"]/sm ) {
			require Text::Balanced;
			if ( my $quotelike = Text::Balanced::extract_quotelike( $self->{remaining} ) ) {
				return bless( [ Type::Parser::QUOTELIKE, $quotelike ], "Type::Parser::Token" );
			}
		}
		
		if ( $self->{remaining} =~ /^([+-]?[\w:.+]+)/sm ) {
			my $spelling = $1;
			substr( $self->{remaining}, 0, length $spelling ) = "";
			
			if ( $spelling =~ /::$/sm ) {
				return bless( [ Type::Parser::CLASS, $spelling ], "Type::Parser::Token" );
			}
			elsif ( $spelling =~ /^[+-]?0x[0-9A-Fa-f]+$/sm ) {
				return bless( [ Type::Parser::HEXNUM, $spelling ], "Type::Parser::Token" );
			}
			elsif ( looks_like_number( $spelling ) ) {
				return bless( [ Type::Parser::STRING, $spelling ], "Type::Parser::Token" );
			}
			elsif ( $self->{remaining} =~ /^\s*=>/sm )    # peek ahead
			{
				return bless( [ Type::Parser::STRING, $spelling ], "Type::Parser::Token" );
			}
			elsif ( $spelling eq "slurpy" ) {
				return $punctuation{$spelling};
			}
			
			return bless( [ Type::Parser::TYPE, $spelling ], "Type::Parser::Token" );
		} #/ if ( $self->{remaining...})
		
		my $rest = $self->{remaining};
		$self->{remaining} = "";
		return bless( [ Type::Parser::MYSTERY, $rest ], "Type::Parser::Token" );
	} #/ sub _read_token
}

1;

__END__

=pod

=encoding utf-8

=for stopwords non-whitespace

=head1 NAME

Type::Parser - parse type constraint strings

=head1 SYNOPSIS

 use v5.10;
 use strict;
 use warnings;
 
 use Type::Parser qw( eval_type );
 use Type::Registry;
 
 my $reg = Type::Registry->for_me;
 $reg->add_types("Types::Standard");
 
 my $type = eval_type("Int | ArrayRef[Int]", $reg);
 
 $type->check(10);        # true
 $type->check([1..4]);    # true
 $type->check({foo=>1});  # false

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

Generally speaking, you probably don't want to be using this module directly.
Instead use the C<< lookup >> method from L<Type::Registry> which wraps it.

=head2 Functions

=over

=item C<< parse($string) >>

Parse the type constraint string into something like an AST.

If called in list context, also returns any "tail" found on the original string.

=item C<< extract_type($string, $registry) >>

Compile a type constraint string into a L<Type::Tiny> object.

If called in list context, also returns any "tail" found on the original string.

=item C<< eval_type($string, $registry) >>

Compile a type constraint string into a L<Type::Tiny> object.

Throws an error if the "tail" contains any non-whitespace character.

=back

=head2 Constants

The following constants correspond to values returned by C<< $token->type >>.

=over

=item C<< TYPE >>

=item C<< QUOTELIKE >>

=item C<< STRING >>

=item C<< HEXNUM >>

=item C<< CLASS >>

=item C<< L_BRACKET >>

=item C<< R_BRACKET >>

=item C<< COMMA >>

=item C<< SLURPY >>

=item C<< UNION >>

=item C<< INTERSECT >>

=item C<< SLASH >>

=item C<< NOT >>

=item C<< L_PAREN >>

=item C<< R_PAREN >>

=item C<< MYSTERY >>

=back

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Type::Registry>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013-2014, 2017-2022 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
