# INTERNAL MODULE: OO backend for Type::Params signatures.

package Type::Params::Signature;

use 5.008001;
use strict;
use warnings;

BEGIN {
	if ( $] < 5.010 ) { require Devel::TypeTiny::Perl58Compat }
}

BEGIN {
	$Type::Params::Signature::AUTHORITY  = 'cpan:TOBYINK';
	$Type::Params::Signature::VERSION    = '2.000001';
}

$Type::Params::Signature::VERSION =~ tr/_//d;

use B ();
use Eval::TypeTiny::CodeAccumulator;
use Types::Standard qw( -is -types -assert );
use Types::TypeTiny qw( -is -types to_TypeTiny );
use Type::Params::Parameter;

sub _croak {
	require Error::TypeTiny;
	return Error::TypeTiny::croak( pop );
}

sub _new_parameter {
	shift;
	'Type::Params::Parameter'->new( @_ );
}

sub _new_code_accumulator {
	shift;
	'Eval::TypeTiny::CodeAccumulator'->new( @_ );
}

sub new {
	my $class = shift;
	my %self  = @_ == 1 ? %{$_[0]} : @_;
	my $self = bless \%self, $class;
	$self->{parameters}   ||= [];
	$self->{class_prefix} ||= 'Type::Params::OO::Klass';
	$self->BUILD;
	return $self;
}

{
	my $klass_id;
	my %klass_cache;
	sub BUILD {
		my $self = shift;

		if ( $self->{named_to_list} and not ref $self->{named_to_list} ) {
			$self->{named_to_list} = [ map $_->name, @{ $self->{parameters} } ];
		}

		if ( delete $self->{rationalize_slurpies} ) {
			$self->_rationalize_slurpies;
		}

		if ( $self->{method} ) {
			my $type = $self->{method};
			$type =
				is_Int($type) ? Defined :
				is_Str($type) ? do { require Type::Utils; Type::Utils::dwim_type( $type, $self->{package} ? ( for => $self->{package} ) : () ) } :
				to_TypeTiny( $type );
			unshift @{ $self->{head} ||= [] }, $self->_new_parameter(
				name    => 'invocant',
				type    => $type,
			);
		}

		if ( defined $self->{bless} and $self->{bless} eq 1 and not $self->{named_to_list} ) {
			my $klass_key     = $self->_klass_key;
			$self->{bless}    = ( $klass_cache{$klass_key} ||= sprintf( '%s%d', $self->{class_prefix}, ++$klass_id ) );
			$self->{oo_trace} = 1 unless exists $self->{oo_trace};
			$self->make_class;
		}
		if ( is_ArrayRef $self->{class} ) {
			$self->{constructor} = $self->{class}->[1];
			$self->{class}       = $self->{class}->[0];
		}
	}
}

sub _klass_key {
	my $self = shift;

	my @parameters = @{ $self->parameters };
	if ( $self->has_slurpy ) {
		push @parameters, $self->slurpy;
	}

	no warnings 'uninitialized';
	join(
		'|',
		map sprintf( '%s*%s*%s', $_->name, $_->getter, $_->predicate ),
		sort { $a->{name} cmp $b->{name} } @parameters
	);
}

sub _rationalize_slurpies {
	my $self = shift;

	my $parameters = $self->parameters;

	if ( $self->is_named ) {
		my ( @slurpy, @rest );

		for my $parameter ( @$parameters ) {
			if ( $parameter->type->is_strictly_a_type_of( Slurpy ) ) {
				push @slurpy, $parameter;
			}
			elsif ( $parameter->{slurpy} ) {
				$parameter->{type} = Slurpy[ $parameter->type ];
				push @slurpy, $parameter;
			}
			else {
				push @rest, $parameter;
			}
		}

		if ( @slurpy == 1 ) {
			my $constraint = $slurpy[0]->type;
			if ( $constraint->type_parameter && $constraint->type_parameter->{uniq} == Any->{uniq} or $constraint->my_slurp_into eq 'HASH' ) {
				$self->{slurpy} = $slurpy[0];
				@$parameters = @rest;
			}
			else {
				$self->_croak( 'Signatures with named parameters can only have slurpy parameters which are a subtype of HashRef' );
			}
		}
		elsif ( @slurpy ) {
			$self->_croak( 'Found multiple slurpy parameters! There can be only one' );
		}
	}
	elsif ( @$parameters ) {
		if ( $parameters->[-1]->type->is_strictly_a_type_of( Slurpy ) ) {
			$self->{slurpy} = pop @$parameters;
		}
		elsif ( $parameters->[-1]{slurpy} ) {
			$self->{slurpy} = pop @$parameters;
			$self->{slurpy}{type} = Slurpy[ $self->{slurpy}{type} ];
		}

		for my $parameter ( @$parameters ) {
			if ( $parameter->type->is_strictly_a_type_of( Slurpy ) or $parameter->{slurpy} ) {
				$self->_croak( 'Parameter following slurpy parameter' );
			}
		}
	}

	if ( $self->{slurpy} and $self->{slurpy}->has_default ) {
		require Carp;
		our @CARP_NOT = ( __PACKAGE__, 'Type::Params' );
		Carp::carp( "Warning: the default for the slurpy parameter will be ignored, continuing anyway" );
		delete $self->{slurpy}{default};
	}
}

sub _parameters_from_list {
	my ( $class, $style, $list, %opts ) = @_;
	my @return;
	my $is_named = ( $style eq 'named' );

	while ( @$list ) {
		my ( $type, %param_opts );
		if ( $is_named ) {
			$param_opts{name} = assert_Str( shift( @$list ) );
		}
		if ( is_HashRef $list->[0] and exists $list->[0]{slurpy} and not is_Bool $list->[0]{slurpy} ) {
			my %new_opts = %{ shift( @$list ) };
			$type = delete $new_opts{slurpy};
			%param_opts = ( %param_opts, %new_opts, slurpy => 1 );
		}
		else {
			$type = shift( @$list );
		}
		if ( is_HashRef( $list->[0] ) ) {
			unless ( exists $list->[0]{slurpy} and not is_Bool $list->[0]{slurpy} ) {
				%param_opts = ( %param_opts, %{ +shift( @$list ) } );
			}
		}
		$param_opts{type} =
			is_Int($type) ? ( $type ? Any : do { $param_opts{optional} = !!1; Any; } ) :
			is_Str($type) ? do { require Type::Utils; Type::Utils::dwim_type( $type, $opts{package} ? ( for => $opts{package} ) : () ) } :
			to_TypeTiny( $type );
		my $parameter = $class->_new_parameter( %param_opts );
		push @return, $parameter;
	}

	return \@return;
}

sub new_from_compile {
	my $class = shift;
	my $style = shift;
	my $is_named = ( $style eq 'named' );

	my %opts  = ();
	while ( is_HashRef $_[0] and not exists $_[0]{slurpy} ) {
		%opts = ( %opts, %{ +shift } );
	}

	for my $pos ( qw/ head tail / ) {
		next unless defined $opts{$pos};
		if ( is_Int( $opts{$pos} ) ) {
			$opts{$pos} = [ ( Any ) x $opts{$pos} ];
		}
		$opts{$pos} = $class->_parameters_from_list( positional => $opts{$pos}, %opts );
	}

	my $list = [ @_ ];
	$opts{is_named}   = $is_named;
	$opts{parameters} = $class->_parameters_from_list( $style => $list, %opts );

	my $self = $class->new( %opts, rationalize_slurpies => 1 );
	return $self;
}

sub new_from_v2api {
	my ( $class, $opts ) = @_;

	my $positional = delete( $opts->{positional} ) || delete( $opts->{pos} );
	my $named      = delete( $opts->{named} );
	my $multiple   = delete( $opts->{multiple} ) || delete( $opts->{multi} );

	$class->_croak( "Signature must be positional, named, or multiple" )
		unless $positional || $named || $multiple;

	if ( $multiple ) {
		$multiple = [] unless is_ArrayRef $multiple;
		unshift @$multiple, { positional => $positional } if $positional;
		unshift @$multiple, { named      => $named      } if $named;
		require Type::Params::Alternatives;
		return 'Type::Params::Alternatives'->new(
			base_options => $opts,
			alternatives => $multiple,
			sig_class    => $class,
		);
	}

	my ( $sig_kind, $args ) = ( pos => $positional );
	if ( $named ) {
		$opts->{bless} = 1 unless exists $opts->{bless};
		( $sig_kind, $args ) = ( named => $named );
		$class->_croak( "Signature cannot have both positional and named arguments" )
			if $positional;
	}

	return $class->new_from_compile( $sig_kind, $opts, @$args );
}

sub package       { $_[0]{package} }
sub subname       { $_[0]{subname} }
sub description   { $_[0]{description} }     sub has_description   { exists $_[0]{description} }
sub method        { $_[0]{method} }
sub head          { $_[0]{head} }            sub has_head          { exists $_[0]{head} }
sub tail          { $_[0]{tail} }            sub has_tail          { exists $_[0]{tail} }
sub parameters    { $_[0]{parameters} }      sub has_parameters    { exists $_[0]{parameters} }
sub slurpy        { $_[0]{slurpy} }          sub has_slurpy        { exists $_[0]{slurpy} }
sub on_die        { $_[0]{on_die} }          sub has_on_die        { exists $_[0]{on_die} }
sub strictness    { $_[0]{strictness} }      sub has_strictness    { exists $_[0]{strictness} }
sub goto_next     { $_[0]{goto_next} }
sub is_named      { $_[0]{is_named} }
sub bless         { $_[0]{bless} }
sub class         { $_[0]{class} }
sub constructor   { $_[0]{constructor} }
sub named_to_list { $_[0]{named_to_list} }
sub oo_trace      { $_[0]{oo_trace} }

sub method_invocant { $_[0]{method_invocant} = defined( $_[0]{method_invocant} ) ? $_[0]{method_invocant} : 'undef' }

sub can_shortcut {
	return $_[0]{can_shortcut}
		if exists $_[0]{can_shortcut};
	$_[0]{can_shortcut} = !(
		$_[0]->slurpy or
		grep $_->might_supply_new_value, @{ $_[0]->parameters }
	);
}

sub coderef {
	$_[0]{coderef} ||= $_[0]->_build_coderef;
}

sub _build_coderef {
	my $self = shift;
	my $coderef = $self->_new_code_accumulator(
		description => $self->description
			|| sprintf( q{parameter validation for '%s::%s'}, $self->package || '', $self->subname || '__ANON__' )
	);

	$self->_coderef_start( $coderef );
	$self->_coderef_head( $coderef ) if $self->has_head;
	$self->_coderef_tail( $coderef ) if $self->has_tail;
	$self->_coderef_parameters( $coderef );
	if ( $self->has_slurpy ) {
		$self->_coderef_slurpy( $coderef );
	}
	elsif ( $self->is_named ) {
		$self->_coderef_extra_names( $coderef );
	}
	$self->_coderef_end( $coderef );

	return $coderef;
}

sub _coderef_start {
	my ( $self, $coderef ) = ( shift, @_ );

	$coderef->add_line( 'sub {' );
	$coderef->{indent} .= "\t";

	if ( my $next = $self->goto_next ) {
		if ( is_CodeLike $next ) {
			$coderef->add_variable( '$__NEXT__', \$next );
		}
		else {
			$coderef->add_line( 'my $__NEXT__ = shift;' );
			$coderef->add_gap;
		}
	}

	if ( $self->method ) {
		# Passed to parameter defaults
		$self->{method_invocant} = '$__INVOCANT__';
		$coderef->add_line( sprintf 'my %s = $_[0];', $self->method_invocant );
		$coderef->add_gap;
	}

	$self->_coderef_start_extra( $coderef );

	my $extravars = '';
	if ( $self->has_head ) {
		$extravars .= ', @head';
	}
	if ( $self->has_tail ) {
		$extravars .= ', @tail';
	}

	if ( $self->is_named ) {
		$coderef->add_line( "my ( \%out, \%in, \%tmp, \$tmp, \$dtmp$extravars );" );
	}
	elsif ( $self->can_shortcut ) {
		$coderef->add_line( "my ( \%tmp, \$tmp$extravars );" );
	}
	else {
		$coderef->add_line( "my ( \@out, \%tmp, \$tmp, \$dtmp$extravars );" );
	}

	if ( $self->has_on_die ) {
		$coderef->add_variable( '$__ON_DIE__', \ $self->on_die );
	}

	$coderef->add_gap;

	$self->_coderef_check_count( $coderef );

	$coderef->add_gap;

	$self;
}

sub _coderef_start_extra {}

sub _coderef_check_count {
	my ( $self, $coderef ) = ( shift, @_ );

	my $strictness_test = '';
	if ( defined $self->strictness and $self->strictness eq 1 ) {
		$strictness_test = '';
	}
	elsif ( $self->strictness ) {
		$strictness_test = sprintf '( not %s ) or ', $self->strictness;
	}
	elsif ( $self->has_strictness ) {
		return $self;
	}

	my $headtail = 0;
	$headtail += @{ $self->head } if $self->has_head;
	$headtail += @{ $self->tail } if $self->has_tail;

	my $is_named = $self->is_named;
	my $min_args = 0;
	my $max_args = 0;
	my $seen_optional = 0;
	for my $parameter ( @{ $self->parameters } ) {
		if ( $parameter->optional ) {
			++$seen_optional;
			++$max_args;
		}
		else {
			$seen_optional and !$is_named and $self->_croak(
				'Non-Optional parameter following Optional parameter',
			);
			++$max_args;
			++$min_args;
		}
	}

	undef $max_args if $self->has_slurpy;

	if ( $is_named ) {
		my $args_if_hashref  = $headtail + 1;
		my $hashref_index    = @{ $self->head || [] };
		my $arity_if_hash    = $headtail % 2;
		my $min_args_if_hash = $headtail + ( 2 * $min_args );
		my $max_args_if_hash = defined( $max_args )
			? ( $headtail + ( 2 * $max_args ) )
			: undef;

		require List::Util;
		$self->{min_args} = List::Util::min( $args_if_hashref, $min_args_if_hash );
		if ( defined $max_args_if_hash ) {
			$self->{max_args} = List::Util::max( $args_if_hashref, $max_args_if_hash );
		}

		my $extra_conditions = '';
		if ( defined $max_args_if_hash and $min_args_if_hash==$max_args_if_hash ) {
			$extra_conditions .= " && \@_ == $min_args_if_hash"
		}
		else {
			$extra_conditions .= " && \@_ >= $min_args_if_hash"
				if $min_args_if_hash;
			$extra_conditions .= " && \@_ <= $max_args_if_hash"
				if defined $max_args_if_hash;
		}

		$coderef->add_line( $strictness_test . sprintf(
			"\@_ == %d && %s\n\tor \@_ %% 2 == %d%s\n\tor %s;",
			$args_if_hashref,
			HashRef->inline_check( sprintf '$_[%d]', $hashref_index ),
			$arity_if_hash,
			$extra_conditions,
			$self->_make_count_fail(
				coderef   => $coderef,
				got       => 'scalar( @_ )',
			),
		) );
	}
	else {
		$min_args += $headtail;
		$max_args += $headtail if defined $max_args;

		$self->{min_args} = $min_args;
		$self->{max_args} = $max_args;

		if ( defined $max_args and $min_args == $max_args ) {
			$coderef->add_line( $strictness_test . sprintf(
				"\@_ == %d\n\tor %s;",
				$min_args,
				$self->_make_count_fail(
					coderef   => $coderef,
					minimum   => $min_args,
					maximum   => $max_args,
					got       => 'scalar( @_ )',
				),
			) );
		}
		elsif ( $min_args and defined $max_args ) {
			$coderef->add_line( $strictness_test . sprintf(
				"\@_ >= %d && \@_ <= %d\n\tor %s;",
				$min_args,
				$max_args,
				$self->_make_count_fail(
					coderef   => $coderef,
					minimum   => $min_args,
					maximum   => $max_args,
					got       => 'scalar( @_ )',
				),
			) );
		}
		else {
			$coderef->add_line( $strictness_test . sprintf(
				"\@_ >= %d\n\tor %s;",
				$min_args || 0,
				$self->_make_count_fail(
					coderef   => $coderef,
					minimum   => $min_args || 0,
					got       => 'scalar( @_ )',
				),
			) );
		}
	}
}

sub _coderef_head {
	my ( $self, $coderef ) = ( shift, @_ );
	$self->has_head or return;

	my $size = @{ $self->head };
	$coderef->add_line( sprintf(
		'@head = splice( @_, 0, %d );',
		$size,
	) );

	$coderef->add_gap;

	my $i = 0;
	for my $parameter ( @{ $self->head } ) {
		$parameter->_make_code(
			signature   => $self,
			coderef     => $coderef,
			input_slot  => sprintf( '$head[%d]', $i ),
			input_var   => '@head',
			output_slot => sprintf( '$head[%d]', $i ),
			output_var  => undef,
			index       => $i,
			type        => 'head',
			display_var => sprintf( '$_[%d]', $i ),
		);
		++$i;
	}

	$self;
}

sub _coderef_tail {
	my ( $self, $coderef ) = ( shift, @_ );
	$self->has_tail or return;

	my $size = @{ $self->tail };
	$coderef->add_line( sprintf(
		'@tail = splice( @_, -%d );',
		$size,
	) );

	$coderef->add_gap;

	my $i = 0;
	my $n = @{ $self->tail };
	for my $parameter ( @{ $self->tail } ) {
		$parameter->_make_code(
			signature   => $self,
			coderef     => $coderef,
			input_slot  => sprintf( '$tail[%d]', $i ),
			input_var   => '@tail',
			output_slot => sprintf( '$tail[%d]', $i ),
			output_var  => undef,
			index       => $i,
			type        => 'tail',
			display_var => sprintf( '$_[-%d]', $n - $i ),
		);
		++$i;
	}

	$self;
}

sub _coderef_parameters {
	my ( $self, $coderef ) = ( shift, @_ );

	if ( $self->is_named ) {

		$coderef->add_line( sprintf(
			'%%in = ( @_ == 1 and %s ) ? %%{ $_[0] } : @_;',
			HashRef->inline_check( '$_[0]' ),
		) );

		$coderef->add_gap;

		for my $parameter ( @{ $self->parameters } ) {
			my $qname = B::perlstring( $parameter->name );
			$parameter->_make_code(
				signature   => $self,
				coderef     => $coderef,
				is_named    => 1,
				input_slot  => sprintf( '$in{%s}', $qname ),
				output_slot => sprintf( '$out{%s}', $qname ),
				display_var => sprintf( '$_{%s}', $qname ),
				key         => $parameter->name,
				type        => 'named_arg',
			);
		}
	}
	else {
		my $can_shortcut = $self->can_shortcut;
		my $head_size    = $self->has_head ? @{ $self->head } : 0;

		my $i = 0;
		for my $parameter ( @{ $self->parameters } ) {
			$parameter->_make_code(
				signature   => $self,
				coderef     => $coderef,
				is_named    => 0,
				input_slot  => sprintf( '$_[%d]', $i ),
				input_var   => '@_',
				output_slot => ( $can_shortcut ? undef : sprintf( '$_[%d]', $i ) ),
				output_var  => ( $can_shortcut ? undef : '@out' ),
				index       => $i,
				display_var => sprintf( '$_[%d]', $i + $head_size ),
			);
			++$i;
		}
	}
}

sub _coderef_slurpy {
	my ( $self, $coderef ) = ( shift, @_ );
	return unless $self->has_slurpy;

	my $parameter  = $self->slurpy;
	my $constraint = $parameter->type;
	my $slurp_into = $constraint->my_slurp_into;
	my $real_type  = $constraint->my_unslurpy;

	if ( $self->is_named ) {
		$coderef->add_line( 'my $SLURPY = \\%in;' );
	}
	elsif ( $real_type and $real_type->{uniq} == Any->{uniq} ) {

		$coderef->add_line( sprintf(
			'my $SLURPY = [ @_[ %d .. $#_ ] ];',
			scalar( @{ $self->parameters } ),
		) );
	}
	elsif ( $slurp_into eq 'HASH' ) {

		my $index = scalar( @{ $self->parameters } );
		$coderef->add_line( sprintf(
			'my $SLURPY = ( $#_ == %d and ( %s ) ) ? { %%{ $_[%d] } } : ( ( $#_ - %d ) %% 2 ) ? { @_[ %d .. $#_ ] } : %s;',
			$index,
			HashRef->inline_check("\$_[$index]"),
			$index,
			$index,
			$index,
			$self->_make_general_fail(
				coderef   => $coderef,
				message   => sprintf(
					qq{sprintf( "Odd number of elements in %%s", %s )},
					B::perlstring( ( $real_type or $constraint )->display_name ),
				),
			),
		) );
	}
	else {
	
		$coderef->add_line( sprintf(
			'my $SLURPY = [ @_[ %d .. $#_ ] ];',
			scalar( @{ $self->parameters } ),
		) );
	}

	$coderef->add_gap;

	$parameter->_make_code(
		signature   => $self,
		coderef     => $coderef,
		input_slot  => '$SLURPY',
		display_var => '$SLURPY',
		index       => 0,
		$self->is_named
			? ( output_slot => sprintf( '$out{%s}', B::perlstring( $parameter->name ) ) )
			: ( output_var  => '@out' )
	);
}

sub _coderef_extra_names {
	my ( $self, $coderef ) = ( shift, @_ );

	return $self if $self->has_strictness && ! $self->strictness;

	$coderef->add_line( '# Unrecognized parameters' );
	$coderef->add_line( sprintf(
		'%s if %skeys %%in;',
		$self->_make_general_fail(
			coderef   => $coderef,
			message   => 'sprintf( q{Unrecognized parameter%s: %s}, keys( %in ) > 1 ? q{s} : q{}, join( q{, }, sort keys %in ) )',
		),
		defined( $self->strictness ) && $self->strictness ne 1
			? sprintf( '%s && ', $self->strictness )
			: ''
	) );
	$coderef->add_gap;
}

sub _coderef_end {
	my ( $self, $coderef ) = ( shift, @_ );

	if ( $self->bless and $self->oo_trace ) {
		my $package = $self->package;
		my $subname = $self->subname;
		if ( defined $package and defined $subname ) {
			$coderef->add_line( sprintf(
				'$out{"~~caller"} = %s;',
				B::perlstring( "$package\::$subname" ),
			) );
			$coderef->add_gap;
		}
	}

	$self->_coderef_end_extra( $coderef );
	$coderef->add_line( $self->_make_return_expression( is_early => 0 ) . ';' );
	$coderef->{indent} =~ s/\t$//;
	$coderef->add_line( '}' );

	$self;
}

sub _coderef_end_extra {}

sub _make_return_list {
	my $self = shift;

	my @return_list;
	if ( $self->has_head ) {
		push @return_list, '@head';
	}

	if ( not $self->is_named ) {
		push @return_list, $self->can_shortcut ? '@_' : '@out';
	}
	elsif ( $self->named_to_list ) {
		push @return_list, map(
			sprintf( '$out{%s}', B::perlstring( $_ ) ),
			@{ $self->named_to_list },
		);
	}
	elsif ( $self->class ) {
		push @return_list, sprintf(
			'%s->%s( \%%out )',
			B::perlstring( $self->class ),
			$self->constructor || 'new',
		);
	}
	elsif ( $self->bless ) {
		push @return_list, sprintf(
			'bless( \%%out, %s )',
			B::perlstring( $self->bless ),
		);
	}
	else {
		push @return_list, '\%out';
	}

	if ( $self->has_tail ) {
		push @return_list, '@tail';
	}

	return @return_list;
}

sub _make_return_expression {
	my ( $self, %args ) = @_;

	my $list = join q{, }, $self->_make_return_list;

	if ( $self->goto_next ) {
		if ( $list eq '@_' ) {
			return sprintf 'goto( $__NEXT__ )';
		}
		else {
			return sprintf 'do { @_ = ( %s ); goto $__NEXT__ }',
				$list;
		}
	}
	elsif ( $args{is_early} or not exists $args{is_early} ) {
		return sprintf 'return( %s )', $list;
	}
	else {
		return sprintf '( %s )', $list;
	}
}

sub _make_general_fail {
	my ( $self, %args ) = ( shift, @_ );

	return sprintf(
		$self->has_on_die
			? q{return( "Error::TypeTiny"->throw_cb( $__ON_DIE__, message => %s ) )}
			: q{"Error::TypeTiny"->throw( message => %s )},
		$args{message},
	);
}

sub _make_constraint_fail {
	my ( $self, %args ) = ( shift, @_ );

	return sprintf(
		$self->has_on_die
			? q{return( Type::Tiny::_failed_check( %d, %s, %s, varname => %s, on_die => $__ON_DIE__ ) )}
			: q{Type::Tiny::_failed_check( %d, %s, %s, varname => %s )},
		$args{constraint}{uniq},
		B::perlstring( $args{constraint}->display_name ),
		$args{varname},
		B::perlstring( $args{display_var} || $args{varname} ),
	);
}

sub _make_count_fail {
	my ( $self, %args ) = ( shift, @_ );

	my @counts;
	if ( $args{got} ) {
		push @counts, sprintf(
			'got => %s',
			$args{got},
		);
	}
	for my $c ( qw/ minimum maximum / ) {
		is_Int( $args{$c} ) or next;
		push @counts, sprintf(
			'%s => %s',
			$c,
			$args{$c},
		);
	}

	return sprintf(
		$self->has_on_die
			? q{return( "Error::TypeTiny::WrongNumberOfParameters"->throw_cb( $__ON_DIE__, %s ) )}
			: q{"Error::TypeTiny::WrongNumberOfParameters"->throw( %s )},
		join( q{, }, @counts ),
	);
}

sub class_attributes {
	my $self = shift;
	$self->{class_attributes} ||= $self->_build_class_attributes;
}

sub _build_class_attributes {
	my $self = shift;
	my %predicates;
	my %getters;

	my @parameters = @{ $self->parameters };
	if ( $self->has_slurpy ) {
		push @parameters, $self->slurpy;
	}

	for my $parameter ( @parameters ) {

		my $name = $parameter->name;
		if ( my $predicate = $parameter->predicate ) {
			$predicate =~ /^[^0-9\W]\w*$/
				or $self->_croak( "Bad accessor name: \"$predicate\"" );
			$predicates{$predicate} = $name;
		}
		if ( my $getter = $parameter->getter ) {
			$getter =~ /^[^0-9\W]\w*$/
				or $self->_croak( "Bad accessor name: \"$getter\"" );
			$getters{$getter} = $name;
		}
	}

	return {
		exists_predicates => \%predicates,
		getters           => \%getters,
	};
}

sub make_class {
	my $self = shift;
	
	my $env = uc( $ENV{PERL_TYPE_PARAMS_XS} || 'XS' );
	if ( $env eq 'PP' or $ENV{PERL_ONLY} ) {
		$self->make_class_pp;
	}

	$self->make_class_xs;
}

sub make_class_xs {
	my $self = shift;

	eval {
		require Class::XSAccessor;
		'Class::XSAccessor'->VERSION( '1.17' );
		1;
	} or return $self->make_class_pp;

	my $attr = $self->class_attributes;

	'Class::XSAccessor'->import(
		class => $self->bless,
		replace => 1,
		%$attr,
	);
}

sub make_class_pp {
	my $self = shift;

	my $code = $self->make_class_pp_code;
	do {
		local $@;
		eval( $code ) or die( $@ );
	};
}

sub make_class_pp_code {
	my $self = shift;

	return ''
		unless $self->is_named && $self->bless && !$self->named_to_list;

	my $coderef = $self->_new_code_accumulator;
	my $attr    = $self->class_attributes;

	$coderef->add_line( '{' );
	$coderef->{indent} = "\t";
	$coderef->add_line( sprintf( 'package %s;', $self->bless ) );
	$coderef->add_line( 'use strict;' );
	$coderef->add_line( 'no warnings;' );

	for my $function ( sort keys %{ $attr->{getters} } ) {
		my $slot = $attr->{getters}{$function};
		$coderef->add_line( sprintf(
			'sub %s { $_[0]{%s} }',
			$function,
			B::perlstring( $slot ),
		) );
	}

	for my $function ( sort keys %{ $attr->{exists_predicates} } ) {
		my $slot = $attr->{exists_predicates}{$function};
		$coderef->add_line( sprintf(
			'sub %s { exists $_[0]{%s} }',
			$function,
			B::perlstring( $slot ),
		) );
	}
	
	$coderef->add_line( '1;' );
	$coderef->{indent} = "";
	$coderef->add_line( '}' );

	return $coderef->code;
}

sub return_wanted {
	my $self = shift;
	my $coderef = $self->coderef;

	if ( $self->{want_source} ) {
		return $coderef->code;
	}
	elsif ( $self->{want_object} ) { # undocumented for now
		return $self;
	}
	elsif ( $self->{want_details} ) {
		return {
			min_args         => $self->{min_args},
			max_args         => $self->{max_args},
			environment      => $coderef->{env},
			source           => $coderef->code,
			closure          => $coderef->compile,
			named            => $self->is_named,
			class_definition => $self->make_class_pp_code,
		};
	}

	return $coderef->compile;
}

1;
