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

require './xmlrpc-lib.pl';

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
