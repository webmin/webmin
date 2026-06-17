#!/usr/local/bin/perl
# Handles xml-rpc requests from arbitrary clients. Each is a call to a
# function in a Webmin module.

use strict;
use warnings;

our ($command_line, $no_acl_check, $force_lang, $trust_unknown_referers);

BEGIN { push(@INC, "."); };
use WebminCore;
use POSIX;
use Socket;

unless (caller) {

if (!$ENV{'GATEWAY_INTERFACE'}) {
	# Command-line mode
	$no_acl_check++;
	$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
	$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
	if ($0 =~ /^(.*\/)[^\/]+$/) {
		chdir($1);
		}
	chomp(my $pwd = `pwd`);
	$0 = "$pwd/xmlrpc.pl";
	$command_line = 1;
	$> == 0 || die "xmlrpc.cgi must be run as root";
	}

$main::allow_rpc_only = 1;
$force_lang = $default_lang;
$trust_unknown_referers = 2;	# Only trust if referer was not set
&init_config();
$main::error_must_die = 1;

# Can this user make remote calls? webmin_user_can_rpc() centralises the
# policy (rpc=0 none, 1 all, 2 admin-only, 3 RPC-only). If the rpc ACL is
# unset, it falls back to allowing only standard admin usernames.
if (!$command_line && !&webmin_user_can_rpc()) {
	&error_exit(1, "Invalid user for RPC");
	}

# Load the XML parser module
eval { require XML::Parser; 1 }
	or &error_exit(2, "XML::Parser Perl module is not installed");

# Read in the XML
my $rawxml = "";
if ($command_line) {
	# From STDIN
	while(<STDIN>) {
		$rawxml .= $_;
		}
	}
else {
	# From web client
	my $clen = $ENV{'CONTENT_LENGTH'} || 0;
	while(length($rawxml) < $clen) {
		my $buf;
		my $got = read(STDIN, $buf, $clen - length($rawxml));
		if ($got <= 0) {
			&error_exit(3, "Failed to read $clen bytes");
			}
		$rawxml .= $buf;
		}
	}

# Parse the XML
my $parser = XML::Parser->new('Style' => 'Tree');
my $xml;
eval { $xml = $parser->parse($rawxml); };
if ($@) {
	&error_exit(4, "Invalid XML : $@");
	}

# Look for the method calls, and invoke each one
my %done_require_module;
my $xmlrv = "<?xml version=\"1.0\" encoding=\"$default_charset\"?>\n";
foreach my $mc (&find_xmls("methodCall", $xml)) {
	# Find the method name and module
	my ($mn) = &find_xmls("methodName", $mc);
	my ($mod, $func) = $mn->[1]->[2] =~ /::/ ?
				split(/::/, $mn->[1]->[2]) :
			   $mn->[1]->[2] =~ /\./ ?
				split(/\./, $mn->[1]->[2]) :
				(undef, $mn->[1]->[2]);

	# Find the parameters
	my ($params) = &find_xmls("params", $mc);
	my @params = &find_xmls("param", $params);
	my @args;
	foreach my $p (@params) {
		my ($value) = &find_xmls("value", $p, 1);
		my $perlv = &parse_xml_value($value);
		push(@args, $perlv);
		}

	# Require the module, if needed
	if ($mod) {
		if (!$done_require_module{$mod}) {
			if (!&foreign_check($mod)) {
				&error_exit(5,
					"Webmin module $mod does not exist");
				}
			eval { &foreign_require($mod); };
			if ($@) {
				$xmlrv .= &make_error_xml(6,
					"Failed to load module $mod : $@");
				last;
				}
			}
		}

	# Call the function
	my @rv;
	if ($func eq "eval") {
		# Execute some Perl code
		@rv = eval $args[0];	## no critic (ProhibitStringyEval)
		if ($@) {
			$xmlrv .= &make_error_xml(8, "Eval failed : $@");
			}
		}
	else {
		# A real function call
		eval { @rv = &foreign_call($mod, $func, @args); };
		if ($@) {
			$xmlrv .= &make_error_xml(7,
				"Function call $func failed : $@");
			last;
			}
		}

	# Encode the results
	$xmlrv .= "<methodResponse>\n";
	$xmlrv .= "<params>\n";
	$xmlrv .= "<param><value>\n";
	if (@rv == 1) {
		$xmlrv .= &encode_xml_value($rv[0]);
		}
	else {
		$xmlrv .= &encode_xml_value(\@rv);
		}
	$xmlrv .= "</value></param>\n";
	$xmlrv .= "</params>\n";
	$xmlrv .= "</methodResponse>\n";
	}

# Flush all modified files, as some APIs require a call to this function
&flush_file_lines();

# Return results to caller
if (!$command_line) {
	print "Content-type: text/xml\n";
	print "Content-length: ",length($xmlrv),"\n";
	print "\n";
	}
print $xmlrv;

} # end of unless (caller)

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

# error_exit(code, message)
# Output an XML error message
sub error_exit
{
my ($code, $msg) = @_;
$msg =~ s/\r|\n$//;
$msg =~ s/\r|\n/ /g;

# Construct error XML
my $xmlerr = "<?xml version=\"1.0\"?>\n";
$xmlerr .= &make_error_xml($code, $msg);

# Send the error XML
if (!$command_line) {
	print "Content-type: text/xml\n";
	print "Content-length: ",length($xmlerr),"\n";
	print "\n";
	}
print $xmlerr;
exit($command_line ? $code : 0);
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

