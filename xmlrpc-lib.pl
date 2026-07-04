# Common XML-RPC request and response marshalling functions

BEGIN { push(@INC, "."); };
use WebminCore;
use strict;
use warnings;

# parse_xml_value(&value)
# Given a <value> object, returns a Perl scalar, hash ref or array ref for
# the contents
sub parse_xml_value
{
my ($value) = @_;
my ($scalar) = &find_xmls([ "int", "i4", "boolean", "string", "double" ],
			  $value, 1);
my ($date) = &find_xmls([ "dateTime.iso8601" ], $value, 1);
my ($base64) = &find_xmls("base64", $value, 1);
my ($struct) = &find_xmls("struct", $value, 1);
my ($array) = &find_xmls("array", $value, 1);
if ($scalar) {
	return $scalar->[1]->[2];
	}
elsif ($date) {
	# Need to decode date
	# XXX format?
	}
elsif ($base64) {
	# Convert to binary
	return &decode_base64($base64->[1]->[2]);
	}
elsif ($struct) {
	# Parse member names and values
	my %rv;
	foreach my $member (&find_xmls("member", $struct, 1)) {
		my ($name) = &find_xmls("name", $member, 1);
		my ($value) = &find_xmls("value", $member, 1);
		my $perlv = &parse_xml_value($value);
		$rv{$name->[1]->[2]} = $perlv;
		}
	return \%rv;
	}
elsif ($array) {
	# Parse data values
	my @rv;
	my ($data) = &find_xmls("data", $array, 1);
	foreach my $value (&find_xmls("value", $data, 1)) {
		my $perlv = &parse_xml_value($value);
		push(@rv, $perlv);
		}
	return \@rv;
	}
else {
	# Fallback - just a string directly in the value
	return $value->[1]->[2];
	}
}

# encode_xml_value(string|int|&hash|&array)
# Given a Perl object, returns XML lines representing it for return to a caller
sub encode_xml_value
{
my ($perlv) = @_;
if (ref($perlv) eq "ARRAY") {
	# Convert to array XML format
	my $xmlrv = "<array>\n<data>\n";
	foreach my $v (@$perlv) {
		$xmlrv .= "<value>\n";
		$xmlrv .= &encode_xml_value($v);
		$xmlrv .= "</value>\n";
		}
	$xmlrv .= "</data>\n</array>\n";
	return $xmlrv;
	}
elsif (ref($perlv) eq "HASH") {
	# Convert to struct XML format
	my $xmlrv = "<struct>\n";
	foreach my $k (keys %$perlv) {
		$xmlrv .= "<member>\n";
		$xmlrv .= "<name>".&html_escape($k)."</name>\n";
		$xmlrv .= "<value>\n";
		$xmlrv .= &encode_xml_value($perlv->{$k});
		$xmlrv .= "</value>\n";
		$xmlrv .= "</member>\n";
		}
	$xmlrv .= "</struct>\n";
	return $xmlrv;
	}
elsif ($perlv =~ /^\-?\d+$/) {
	# Return an integer
	return "<int>$perlv</int>\n";
	}
elsif ($perlv =~ /^\-?\d*\.\d+$/) {
	# Return a double
	return "<double>$perlv</double>\n";
	}
elsif ($perlv =~ /^[\40-\377]*$/) {
	# Return a scalar
	return "<string>".&html_escape($perlv)."</string>\n";
	}
else {
	# Contains non-printable characters, so return as base64
	return "<base64>".&encode_base64($perlv)."</base64>\n";
	}
}

# find_xmls(name|&names, &config, [depth])
# Returns the XMLs object with some name, by recursively searching the XML
sub find_xmls
{
my ($name, $conf, $depth) = @_;
my @m = ref($name) ? @$name : ( $name );
if (&indexoflc($conf->[0], @m) >= 0) {
        # Found it!
        return ( $conf );
        }
else {
        # Need to recursively scan all sub-elements, except for the first
        # which is just the tags of this element
	if (defined($depth) && !$depth) {
		# Gone too far .. stop
		return ( );
		}
        my $list = $conf->[1];
        # A char-data leaf has a plain string here, not a child list. There
        # is nothing to scan, so stop before dereferencing it as an array.
        ref($list) eq 'ARRAY' || return ( );
        my @rv;
        for(my $i=1; $i<@$list; $i+=2) {
                my @srv = &find_xmls($name,
                                       [ $list->[$i], $list->[$i+1] ],
				       defined($depth) ? $depth-1 : undef);
                push(@rv, @srv);
                }
        return @rv;
        }
return ( );
}

# make_error_xml(code, message)
# Returns an XML methodResponse fault document for the given code and message
sub make_error_xml
{
my ($code, $msg) = @_;
my $xmlerr = "<methodResponse>\n";
$xmlerr .= "<fault>\n";
$xmlerr .= "<value>\n";
$xmlerr .= &encode_xml_value( { 'faultCode' => $code,
				'faultString' => $msg });
$xmlerr .= "</value>\n";
$xmlerr .= "</fault>\n";
$xmlerr .= "</methodResponse>\n";
return $xmlerr;
}

1;
