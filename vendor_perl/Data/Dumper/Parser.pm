package Data::Dumper::Parser;

use strict;
use warnings;

our $VERSION = '0.01';

# parse(string)
# Parses supported Data::Dumper output without evaluating Perl code. Dies on
# invalid or unsupported syntax.
sub parse
{
my ($str) = @_;
defined($str) && !ref($str) || die "Input must be a string\n";
my $s = \$str;
pos($str) = 0;

# Read the main value.
$str =~ /\G\$VAR1\s*=/gc || die "Missing \$VAR1 assignment\n";
my $root = _parse_value($s, 0);
$str =~ /\G\s*;/gc || die "Missing ; after value\n";

# Apply the assignments that link shared and cyclic references.
while(1) {
	$str =~ /\G\s+/gc;
	last if (pos($str) == length($str));
	my $target = _parse_path($s, \$root);
	$str =~ /\G\s*=\s*/gc || die "Missing = in reference link\n";
	my $value;
	if ($str =~ /\G\\/gc) {
		# Reference to an existing slot, like \$VAR1->{'a'}.
		$value = _parse_path($s, \$root);
		}
	else {
		# Copy of an existing value, like $VAR1->{'a'}.
		$value = ${_parse_path($s, \$root)};
		}
	$str =~ /\G\s*;/gc || die "Missing ; after reference link\n";
	$$target = $value;
	}
return $root;
}

# _parse_value(&string, depth)
# Reads one value at the current string position.
sub _parse_value
{
my ($s, $depth) = @_;
# Recursive parsing is bounded explicitly below.
no warnings 'recursion';
$depth < 1000 || die "Data is nested too deeply\n";
$$s =~ /\G\s+/gc;
if ($$s =~ /\G'/gc) {
	return _parse_single($s);
	}
elsif ($$s =~ /\G"/gc) {
	return _parse_double($s);
	}
elsif ($$s =~ /\G!!([01])(?![A-Za-z0-9_.])/gc) {
	# Read native boolean literals without evaluating arbitrary expressions.
	return $1 eq '1';
	}
elsif ($$s =~ /\G(-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][-+]?[0-9]+)?)(?![A-Za-z0-9_.])/gc) {
	# Return an unquoted number as a numeric scalar.
	return $1 + 0;
	}
elsif ($$s =~ /\G\{/gc) {
	# Read a hash of key/value pairs.
	my $rv = { };
	return $rv if ($$s =~ /\G\s*\}/gc);
	while(1) {
		$$s =~ /\G\s+/gc;
		my $key = _parse_key($s);
		$$s =~ /\G\s*=>/gc || die "Missing => in hash\n";
		$rv->{$key} = _parse_value($s, $depth+1);
		if ($$s =~ /\G\s*,/gc) {
			# Continue unless this is a trailing comma.
			return $rv if ($$s =~ /\G\s*\}/gc);
			}
		elsif ($$s =~ /\G\s*\}/gc) {
			# Accept a closing brace without a trailing comma.
			return $rv;
			}
		else {
			# Reject all other separators.
			die "Missing , or } in hash\n";
			}
		}
	}
elsif ($$s =~ /\G\[/gc) {
	# Read an array of values.
	my $rv = [ ];
	return $rv if ($$s =~ /\G\s*\]/gc);
	while(1) {
		push(@$rv, _parse_value($s, $depth+1));
		if ($$s =~ /\G\s*,/gc) {
			# Continue unless this is a trailing comma.
			return $rv if ($$s =~ /\G\s*\]/gc);
			}
		elsif ($$s =~ /\G\s*\]/gc) {
			# Accept a closing bracket without a trailing comma.
			return $rv;
			}
		else {
			# Reject all other separators.
			die "Missing , or ] in array\n";
			}
		}
	}
elsif ($$s =~ /\G\\/gc) {
	# Read a reference to a new scalar, like \'text'.
	my $v = _parse_value($s, $depth+1);
	return \$v;
	}
elsif ($$s =~ /\Gundef(?![A-Za-z0-9_:])/gc) {
	return undef;
	}
elsif ($$s =~ /\Gbless\(/gc) {
	# Keep an object's data without blessing it into its remote class.
	my $rv = _parse_value($s, $depth+1);
	$$s =~ /\G\s*,\s*/gc || die "Missing , in bless\n";
	if ($$s =~ /\G'/gc) {
		_parse_single($s);
		}
	elsif ($$s =~ /\G"/gc) {
		_parse_double($s);
		}
	else {
		# Reject a malformed or executable class expression.
		die "Missing class name in bless\n";
		}
	$$s =~ /\G\s*\)/gc || die "Missing ) in bless\n";
	return $rv;
	}
elsif ($$s =~ /\Gdo\{my \$o\}/gc) {
	# Leave a placeholder for a later reference-link assignment.
	return undef;
	}
elsif ($$s =~ /\Gdo\{\\\(my \$o =/gc) {
	# Read the scalar reference used for a blessed scalar reference.
	my $v = _parse_value($s, $depth+1);
	$$s =~ /\G\s*\)\}/gc || die "Missing )} in scalar ref\n";
	return \$v;
	}
elsif ($$s =~ /\Gsub \{ "DUMMY" \}/gc) {
	# Do not transfer code references.
	return undef;
	}
elsif ($$s =~ /\Gqr\//gc) {
	# Return a regexp as its pattern string without compiling it.
	my $pat = '';
	while(1) {
		if ($$s =~ /\G([^\/\\]+)/gc) {
			$pat .= $1;
			}
		elsif ($$s =~ /\G(\\.)/gcs) {
			$pat .= $1;
			}
		elsif ($$s =~ /\G\//gc) {
			last;
			}
		else {
			# Reject an incomplete regexp instead of compiling it.
			die "Unterminated regexp\n";
			}
		}
	my $flags = $$s =~ /\G([a-z]+)/gc ? $1 : '';
	return "(?^$flags:$pat)";
	}
elsif ($$s =~ /\G\*(?:[A-Za-z_][A-Za-z0-9_]*)?(?:::[A-Za-z0-9_]+)+/gc) {
	# Do not transfer globs.
	return undef;
	}
elsif ($$s =~ /\G\*\{/gc) {
	# Read a glob with an unusual name, like *{'::odd name'}.
	if ($$s =~ /\G'/gc) {
		_parse_single($s);
		}
	elsif ($$s =~ /\G"/gc) {
		_parse_double($s);
		}
	else {
		# Reject any other glob expression.
		die "Invalid glob name\n";
		}
	$$s =~ /\G\}/gc || die "Missing } in glob\n";
	return undef;
	}
elsif (substr($$s, pos($$s), 1) eq '$') {
	# Match eval by using undef until a later assignment resolves this link.
	_parse_path($s);
	return undef;
	}
die "Unsupported data at position ".pos($$s)."\n";
}

# _parse_path(&string, [&root])
# Reads a path such as ${$VAR1->{'a'}}->[0]. If root is supplied, returns a
# reference to the existing slot. Without root, only validates the syntax.
sub _parse_path
{
my ($s, $root) = @_;
my $slot;
if ($$s =~ /\G\$\{/gc) {
	# Follow a scalar reference such as ${$VAR1}.
	my $inner = _parse_path($s, $root);
	$$s =~ /\G\}/gc || die "Missing } in reference path\n";
	if ($root) {
		# Resolve the dereference only when an actual root was supplied.
		my $type = ref($$inner);
		$type eq 'SCALAR' || $type eq 'REF' ||
			die "Reference path does not match the data\n";
		$slot = $$inner;
		}
	}
elsif ($$s =~ /\G\$VAR1(?![A-Za-z0-9_:])/gc) {
	# Start at the root value.
	$slot = $root;
	}
else {
	# Reject paths that do not begin at the serialized root.
	die "Invalid reference path\n";
	}

# Follow hash and array subscripts. The first requires an arrow because Perl
# would otherwise parse a different variable.
my $need_arrow = 1;
while(1) {
	my $arrow = $$s =~ /\G->/gc;
	my $next = substr($$s, pos($$s), 1);
	if ($next ne '{' && $next ne '[') {
		$arrow && die "Missing subscript in reference path\n";
		last;
		}
	$need_arrow && !$arrow && die "Missing -> in reference path\n";
	$need_arrow = 0;
	if ($$s =~ /\G\{/gc) {
		# Refuse links to hash elements outside the parsed data.
		my $key = _parse_key($s);
		$$s =~ /\G\}/gc || die "Missing } in reference path\n";
		next if (!$root);
		ref($$slot) eq 'HASH' && exists($$slot->{$key}) ||
			die "Reference path does not match the data\n";
		$slot = \$$slot->{$key};
		}
	elsif ($$s =~ /\G\[([0-9]+)\]/gc) {
		# Refuse links to array elements outside the parsed data.
		my $i = $1;
		next if (!$root);
		ref($$slot) eq 'ARRAY' && $i < @{$$slot} ||
			die "Reference path does not match the data\n";
		$slot = \$$slot->[$i];
		}
	else {
		# Reject an unsupported path component.
		die "Invalid subscript in reference path\n";
		}
	}
return $slot;
}

# _parse_key(&string)
# Reads a quoted, bare-word or integer hash key.
sub _parse_key
{
my ($s) = @_;
if ($$s =~ /\G'/gc) {
	return _parse_single($s);
	}
elsif ($$s =~ /\G"/gc) {
	return _parse_double($s);
	}
elsif ($$s =~ /\G(-?[A-Za-z_][A-Za-z0-9_]*|-?(?:0|[1-9][0-9]*))(?![A-Za-z0-9_'"])/gc) {
	return $1;
	}
die "Invalid hash key at position ".pos($$s)."\n";
}

# _parse_single(&string)
# Reads a single-quoted string. Only \\ and \' are escapes.
sub _parse_single
{
my ($s) = @_;
my $rv = '';
while(1) {
	if ($$s =~ /\G([^'\\]+)/gc) {
		$rv .= $1;
		}
	elsif ($$s =~ /\G'/gc) {
		return $rv;
		}
	elsif ($$s =~ /\G\\([\\'])/gc) {
		$rv .= $1;
		}
	elsif ($$s =~ /\G\\/gc) {
		# Preserve a backslash that does not escape a quote or backslash.
		$rv .= "\\";
		}
	else {
		# Reject an incomplete quoted string.
		die "Unterminated string\n";
		}
	}
}

# _parse_double(&string)
# Reads a double-quoted string without using Perl interpolation. Rejects an
# unescaped $ or @ and unsupported escapes.
sub _parse_double
{
my ($s) = @_;
my $rv = '';
while(1) {
	if ($$s =~ /\G([^"\\\$\@]+)/gc) {
		$rv .= $1;
		}
	elsif ($$s =~ /\G"/gc) {
		return $rv;
		}
	elsif ($$s =~ /\G\\x\{([0-9A-Fa-f]{1,8})\}/gc) {
		$rv .= chr(hex($1));
		}
	elsif ($$s =~ /\G\\x([0-9A-Fa-f]{1,2})/gc) {
		$rv .= chr(hex($1));
		}
	elsif ($$s =~ /\G\\([0-7]{1,3})/gc) {
		$rv .= chr(oct($1));
		}
	elsif ($$s =~ /\G\\([nrtfbae])/gc) {
		# Decode a named control character.
		$rv .= { 'n' => "\n", 'r' => "\r", 't' => "\t", 'f' => "\f",
			 'b' => "\b", 'a' => "\a", 'e' => "\e" }->{$1};
		}
	elsif ($$s =~ /\G\\([^A-Za-z0-9])/gc) {
		# Decode escaped punctuation, like \" or \$.
		$rv .= $1;
		}
	else {
		# Reject interpolation and unsupported Perl escapes.
		die "Invalid double-quoted string\n";
		}
	}
}

1;

__END__

=head1 NAME

Data::Dumper::Parser - Parse Data::Dumper output without executing it

=head1 SYNOPSIS

  use Data::Dumper::Parser ();

  my $value = Data::Dumper::Parser::parse($dump);

=head1 DESCRIPTION

This module parses the data syntax emitted by Data::Dumper. It does not use
C<eval> and rejects unsupported Perl syntax.

Plain values, scalar references, arrays, hashes, shared references and cyclic
references are preserved. Blessed values become plain data, code references
and globs become undefined values, and regular expressions become strings.

=head1 FUNCTIONS

=head2 parse(string)

Returns the decoded value. Dies if the input is invalid or contains unsupported
syntax.

=head1 AUTHOR

Ilia Ross E<lt>ilia@webmin.devE<gt>

=cut
