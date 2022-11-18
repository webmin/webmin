package Error::TypeTiny;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Error::TypeTiny::AUTHORITY = 'cpan:TOBYINK';
	$Error::TypeTiny::VERSION   = '2.000001';
}

$Error::TypeTiny::VERSION =~ tr/_//d;

require Type::Tiny;
__PACKAGE__->Type::Tiny::_install_overloads(
	q[""]   => sub { $_[0]->to_string },
	q[bool] => sub { 1 },
);

require Carp;
*CarpInternal = \%Carp::CarpInternal;

our %CarpInternal;
$CarpInternal{$_}++ for qw(
	Types::Standard::_Stringable
	Exporter::Tiny
	Eval::TypeTiny::Sandbox
	
	Devel::TypeTiny::Perl56Compat
	Devel::TypeTiny::Perl58Compat
	Error::TypeTiny
	Error::TypeTiny::Assertion
	Error::TypeTiny::Compilation
	Error::TypeTiny::WrongNumberOfParameters
	Eval::TypeTiny
	Reply::Plugin::TypeTiny
	Test::TypeTiny
	Type::Coercion
	Type::Coercion::FromMoose
	Type::Coercion::Union
	Type::Library
	Type::Params
	Type::Parser
	Type::Registry
	Types::Common::Numeric
	Types::Common::String
	Types::Standard
	Types::Standard::ArrayRef
	Types::Standard::CycleTuple
	Types::Standard::Dict
	Types::Standard::HashRef
	Types::Standard::Map
	Types::Standard::ScalarRef
	Types::Standard::StrMatch
	Types::Standard::Tied
	Types::Standard::Tuple
	Types::TypeTiny
	Type::Tiny
	Type::Tiny::Class
	Type::Tiny::Duck
	Type::Tiny::Enum
	Type::Tiny::_HalfOp
	Type::Tiny::Intersection
	Type::Tiny::Role
	Type::Tiny::Union
	Type::Utils
);

sub new {
	my $class  = shift;
	my %params = ( @_ == 1 ) ? %{ $_[0] } : @_;
	return bless \%params, $class;
}

sub throw {
	my $next = $_[0]->can( 'throw_cb' );
	splice( @_, 1, 0, undef );
	goto $next;
}

sub throw_cb {
	my $class = shift;
	my $callback = shift;
	
	my ( $level, @caller, %ctxt ) = 0;
	while (
		do {
			my $caller = caller $level;
			defined $caller and $CarpInternal{$caller};
		}
		)
	{
		$level++;
	}
	if ( ( ( caller( $level - 1 ) )[1] || "" ) =~
		/^(?:parameter validation for|exportable function) '(.+?)'$/ )
	{
		my ( $pkg, $func ) = ( $1 =~ m{^(.+)::(\w+)$} );
		$level++ if caller( $level ) eq ( $pkg || "" );
	}
	
	# Moo's Method::Generate::Constructor puts an eval in the stack trace,
	# that is useless for debugging, so show the stack frame one above.
	$level++
		if (
		( caller( $level ) )[1] =~ /^\(eval \d+\)$/
		and ( caller( $level ) )[3] eq '(eval)'    # (caller())[3] is $subroutine
		);
	@ctxt{qw/ package file line /} = caller( $level );
	
	my $stack = undef;
	if ( our $StackTrace ) {
		require Devel::StackTrace;
		$stack = "Devel::StackTrace"->new(
			ignore_package => [ keys %CarpInternal ],
		);
	}
	
	our $LastError = $class->new(
		context     => \%ctxt,
		stack_trace => $stack,
		@_,
	);
	
	$callback ? $callback->( $LastError ) : die( $LastError );
} #/ sub throw

sub message     { $_[0]{message} ||= $_[0]->_build_message }
sub context     { $_[0]{context} }
sub stack_trace { $_[0]{stack_trace} }

sub to_string {
	my $e = shift;
	my $c = $e->context;
	my $m = $e->message;
	
	$m =~ /\n\z/s
		? $m
		: $c ? sprintf(
		"%s at %s line %s.\n", $m, $c->{file} || 'file?',
		$c->{line} || 'NaN'
		)
		: sprintf( "%s\n", $m );
} #/ sub to_string

sub _build_message {
	return 'An exception has occurred';
}

sub croak {
	my ( $fmt, @args ) = @_;
	@_ = (
		__PACKAGE__,
		message => sprintf( $fmt, @args ),
	);
	goto \&throw;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Error::TypeTiny - exceptions for Type::Tiny and friends

=head1 SYNOPSIS

   use Data::Dumper;
   use Try::Tiny;
   use Types::Standard qw(Str);
   
   try {
      Str->assert_valid(undef);
   }
   catch {
      my $exception = shift;
      warn "Encountered Error: $exception";
      warn Dumper($exception->explain)
         if $exception->isa("Error::TypeTiny::Assertion");
   };

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

When Type::Tiny and its related modules encounter an error, they throw an
exception object. These exception objects inherit from Error::TypeTiny.

=head2 Constructors

=over

=item C<< new(%attributes) >>

Moose-style constructor function.

=item C<< throw(%attributes) >>

Constructs an exception and passes it to C<die>.

Automatically populates C<context> and C<stack_trace> if appropriate.

=item C<< throw_cb($callback, %attributes) >>

Constructs an exception and passes it to C<< $callback >> which should
be a coderef; if undef, uses C<die>.

Automatically populates C<context> and C<stack_trace> if appropriate.

=back

=head2 Attributes

=over

=item C<message>

The error message.

=item C<context>

Hashref containing the package, file and line that generated the error.

=item C<stack_trace>

A more complete stack trace. This feature requires L<Devel::StackTrace>;
use the C<< $StackTrace >> package variable to switch it on.

=back

=head2 Methods

=over

=item C<to_string>

Returns the message, followed by the context if it is set.

=back

=head2 Functions

=over

=item C<< Error::TypeTiny::croak($format, @args) >>

Functional-style shortcut to C<throw> method. Takes an C<sprintf>-style
format string and optional arguments to construct the C<message>.

=back

=head2 Overloading

=over

=item *

Stringification is overloaded to call C<to_string>.

=back

=head2 Package Variables

=over

=item C<< %Carp::CarpInternal >>

Error::TypeTiny honours this package variable from L<Carp>.
(C< %Error::TypeTiny::CarpInternal> is an alias for it.)

=item C<< $Error::TypeTiny::StackTrace >>

Boolean to toggle stack trace generation.

=item C<< $Error::TypeTiny::LastError >>

A reference to the last exception object thrown.

=back

=head1 CAVEATS

Although Error::TypeTiny objects are thrown for errors produced by
Type::Tiny, that doesn't mean every time you use Type::Tiny you'll get
Error::TypeTinys whenever you want.

For example, if you use a Type::Tiny type constraint in a Moose attribute,
Moose will not call the constraint's C<assert_valid> method (which throws
an exception). Instead it will call C<check> and C<get_message> (which do
not), and will C<confess> an error message of its own. (The C<< $LastError >>
package variable may save your bacon.)

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Error::TypeTiny::Assertion>,
L<Error::TypeTiny::WrongNumberOfParameters>.

L<Try::Tiny>, L<Try::Tiny::ByClass>.

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
