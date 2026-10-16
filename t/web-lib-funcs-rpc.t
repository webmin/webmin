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

done_testing();
