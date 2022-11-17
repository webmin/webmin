package Eval::TypeTiny::CodeAccumulator;

use 5.008001;
use strict;
use warnings;

BEGIN {
	if ( $] < 5.010 ) { require Devel::TypeTiny::Perl58Compat }
}

BEGIN {
	$Eval::TypeTiny::CodeAccumulator::AUTHORITY  = 'cpan:TOBYINK';
	$Eval::TypeTiny::CodeAccumulator::VERSION    = '2.000001';
}

$Eval::TypeTiny::CodeAccumulator::VERSION =~ tr/_//d;

sub new {
	my $class = shift;

	my %self  = @_ == 1 ? %{$_[0]} : @_;
	$self{env}          ||= {};
	$self{code}         ||= [];
	$self{placeholders} ||= {};
	$self{indent}       ||= '';

	bless \%self, $class;
}

sub code        { join( "\n", @{ $_[0]{code} } ) }
sub description { $_[0]{description} }
sub env         { $_[0]{env} }

sub add_line {
	my $self = shift;
	my $indent = $self->{indent};

	push @{ $self->{code} }, map { $indent . $_ } map { split /\n/ } @_;

	$self;
}

sub increase_indent {
	$_[0]{indent} .= "\t";
	$_[0];
}

sub decrease_indent {
	$_[0]{indent} =~ s/\t$//;
	$_[0];
}

sub add_gap {
	push @{ $_[0]{code} }, '';
}

sub add_placeholder {
	my ( $self, $for ) = ( shift, @_ );
	my $indent = $self->{indent} || '';

	$self->{placeholders}{$for} = [
		scalar( @{ $self->{code} } ),
		$self->{indent},
	];
	push @{ $self->{code} }, "$indent# placeholder [ $for ]";

	if ( defined wantarray ) {
		return sub { $self->fill_placeholder( $for, @_ ) };
	}
}

sub fill_placeholder {
	my ( $self, $for, @lines ) = ( shift, @_ );

	my ( $line_number, $indent ) = @{ delete $self->{placeholders}{$for} or die };
	my @indented_lines = map { $indent . $_ } map { split /\n/ } @lines;
	splice( @{ $self->{code} }, $line_number, 1, @indented_lines );

	$self;
}

sub add_variable {
	my ( $self, $suggested_name, $reference ) = ( shift, @_ );
	
	my $actual_name = $suggested_name;
	my $i = 1;
	while ( exists $self->{env}{$actual_name} ) {
		$actual_name = sprintf '%s_%d', $suggested_name, ++$i;
	}

	$self->{env}{$actual_name} = $reference;

	$actual_name;
}

sub finalize {
	my $self = shift;

	for my $p ( values %{ $self->{placeholders} } ) {
		splice( @{ $self->{code} }, $p->[0], 1 );
	}

	$self;
}

sub compile {
	my ( $self, %opts ) = ( shift, @_ );

	$self->{finalized}++ or $self->finalize();

	require Eval::TypeTiny;
	return Eval::TypeTiny::eval_closure(
		description  => $self->description,
		%opts,
		source       => $self->code,
		environment  => $self->env,
	);
}

1;

__END__

=pod

=encoding utf-8

=for stopwords pragmas coderefs

=head1 NAME

Eval::TypeTiny::CodeAccumulator - alternative API for Eval::TypeTiny

=head1 SYNOPSIS

  my $make_adder = 'Eval::TypeTiny::CodeAccumulator'->new(
    description => 'adder',
  );
  
  my $n = 40;
  my $varname = $make_adder->add_variable( '$addend' => \$n );
  
  $make_adder->add_line( 'sub {' );
  $make_adder->increase_indent;
  $make_adder->add_line( 'my $other_addend = shift;' );
  $make_adder->add_gap;
  $make_adder->add_line( 'return ' . $varname . ' + $other_addend;' );
  $make_adder->decrease_indent;
  $make_adder->add_line( '}' );
  
  my $adder = $make_adder->compile;
  
  say $adder->( 2 );  ## ==> 42

=head1 STATUS
 
This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

=head2 Constructor

=over

=item C<< new( %attrs ) >>

The only currently supported attribute is C<description>.

=back

=head2 Methods

=over

=item C<< env() >>

Returns the current compilation environment, a hashref of variables to close
over.

=item C<< code() >>

Returns the source code so far.

=item C<< description() >>

Returns the same description given to the constructor, if any.

=item C<< add_line( @lines_of_code ) >>

Adds the next line of code.

=item C<< add_gap() >>

Adds a blank line of code.

=item C<< increase_indent() >>

Increases the indentation level for subsequent lines of code.

=item C<< decrease_indent() >>

Decreases the indentation level for subsequent lines of code.

=item C<< add_variable( $varname, $reference_to_value ) >>

Adds a variable to the compilation environment so that the coderef being
generated can close over it.

If a variable already exists in the environment with that name, will instead
add a variable with a different name and return that name. You should always
continue to refer to the variable with that returned name, just in case.

=item C<< add_placeholder( $placeholder_name ) >>

Adds a line of code which is just a comment, but remembers its line number.

=item C<< fill_placeholder( $placeholder_name, @lines_of_code ) >>

Goes back to a previously inserted placeholder and replaces it with code.

As an alternative, C<add_placeholder> returns a coderef, which you can call
like C<< $callback->( @lines_of_code ) >>.

=item C<< compile( %opts ) >>

Compiles the code and returns it as a coderef.

Options are passed on to C<< eval_closure >> from L<Eval::TypeTiny>,
but cannot include C<code> or C<environment>. C<< alias => 1 >>
is probably the option most likely to be useful, but in general
you won't need to provide any options.

=item C<< finalize() >>

This method is called by C<compile> just before compiling the code. All it
does is remove unfilled placeholder comments. It is not intended for end
users to call, but is documented as it may be a useful hook if you are
subclassing this class.

=back

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Eval::TypeTiny>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2022 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
