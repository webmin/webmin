#!/usr/bin/perl

use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use FindBin;

require "$FindBin::Bin/../web-lib-funcs.pl";

# Capture a regular RPC connection without opening a network socket.
my @connect_args;
my @response;
local *main::remote_session_name = sub { return 'remote.example:10000.test'; };
local *main::foreign_config = sub { return ( 'capath' => '/test/ca' ); };
local *main::make_http_connection = sub {
	@connect_args = @_;
	return { 'mock' => 1 };
	};
local *main::write_http_connection = sub { return 1; };
local *main::read_http_connection = sub { return shift(@response); };
local $main::remote_error_handler = sub { die "$_[0]\n"; };

my $reply = main::serialise_variable({ 'status' => 1, 'rv' => 'ok' });
@response = ("HTTP/1.0 200 OK\r\n", "\r\n", $reply, undef);
my $rv = main::remote_rpc_call(
	{ 'host' => 'remote.example', 'ip' => '192.0.2.10', 'port' => 10000,
	  'ssl' => 1, 'checkssl' => 1, 'user' => 'root', 'pass' => 'secret' },
	{ 'action' => 'ping' });

is($rv, 'ok', 'regular RPC response is returned');
is($connect_args[3], 'POST', 'regular RPC uses POST');
is($connect_args[4], '/rpc.cgi', 'regular RPC uses the expected endpoint');
is_deeply($connect_args[7],
	{ 'host' => 'remote.example', 'self' => 1, 'capath' => '/test/ca' },
	'regular RPC applies certificate verification requirements');

# The automatic fast-RPC probe must use the submitted certificate settings.
{
	local $INC{'./servers-lib.pl'} = 1;
	local %main::access = ( edit => 1, add => 1 );
	local *main::ReadParse = sub { };
	local *main::error_setup = sub { };
	local *main::error = sub { die "$_[0]\n" };
	local *main::get_server = sub { { id => 123, host => 'old.example' } };
	# These probe cases use servers without certificate pins.
	local *main::server_ssl_fingerprints = sub { '' };
	local *main::can_use_server = sub { 1 };
	local *main::to_ipaddress = sub { '192.0.2.10' };
	local *main::webmin_log = sub { };
	local *main::redirect = sub { };
	local *main::close_http_connection = sub { };
	my ($saved, $writes, $reject);
	local *main::save_server = sub { $saved = { %{$_[0]} } };
	# A failed TLS check returns an error string, never a connection handle.
	local *main::make_http_connection = sub {
		@connect_args = @_;
		return $reject && $_[7]
			? 'Invalid SSL certificate : fixture' : { };
		};
	local *main::write_http_connection = sub { $writes .= $_[1] };
	for my $case (
		[ 'checked with CA path', 1, '/test/ca', 0, 2,
		  { host => 'remote.example', self => 1,
		    capath => '/test/ca' } ],
		[ 'checked without CA path', 1, '', 0, 2,
		  { host => 'remote.example', self => 1 } ],
		[ 'unchecked', 0, '/test/ca', 0, 2, undef ],
		[ 'certificate rejected', 1, '/test/ca', 1, 2,
		  { host => 'remote.example', self => 1,
		    capath => '/test/ca' } ],
		[ 'explicit fast', 1, '/test/ca', 0, 1, undef ],
		[ 'explicit slow', 1, '/test/ca', 0, 0, undef ]) {
		# Reset settings, responses and captured writes for each save.
		my ($name, $checkssl, $capath, $invalid, $fast, $reqs) = @$case;
		local %main::config = ( capath => $capath );
		local %main::in = ( id => 123, host => 'remote.example',
			port => 10000, ssl => 1, checkssl => $checkssl,
			mode => 1, fast => $fast, wuser => 'fixture',
			wpass => 'fixture-password' );
		@connect_args = ();
		@response = ("HTTP/1.0 404 Not Found\r\n");
		($saved, $writes, $reject) = ( undef, '', $invalid );
		do "$FindBin::Bin/../servers/save_serv.cgi";
		die $@ if ($@);
		is_deeply($connect_args[7], $reqs,
			  "$name: certificate settings");
		is(scalar(@connect_args) ? 1 : 0, $fast == 2 ? 1 : 0,
		   "$name: only automatic mode probes");
		is($writes =~ /Authorization: basic / ? 1 : 0,
		   $fast == 2 && !$invalid ? 1 : 0,
		   "$name: login requires an accepted connection");
		is($saved->{'fast'}, $fast == 2 ? 0 : $fast,
		   "$name: existing RPC fallback is preserved");
		}
	}

done_testing();
