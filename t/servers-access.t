#!/usr/bin/perl
# Exercise the actual Servers Index ACL and JSON route with synthetic records.
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/..";
use WebminCore;
use Test::More;
our (%access, %in, %text, $remote_user);
{
	no warnings qw(redefine once);
	local *WebminCore::import = sub { };
	local *main::init_config = sub { };
	local *main::get_module_acl = sub { (servers => '*', links => 1, edit => 1) };
	require "$Bin/../servers/servers-lib.pl";
}
$INC{'./servers-lib.pl'} = 1;
my $guest = {id => '123', host => 'guest.test', desc => 'Guest',
	cloudmin_uuid => 'fixture', user => 'fixture', pass => 'synthetic-secret', file => '/private/123.serv'};
my $manual = {id => '456', host => 'manual.test', desc => 'Manual',
	user => 'fixture', pass => 'synthetic-secret', private_future_field => 'secret'};
$remote_user = 'delegated';
ok(can_use_server($guest), 'Cloudmin metadata does not override native wildcard grants');
ok(can_use_server($manual), 'ordinary entries use the same native grants');
local $access{'servers'} = '456';
ok(!can_use_server($guest), 'native entry ACL excludes an unassigned server');
$access{'servers'} = '*';
{
	no warnings qw(redefine once);
	local *main::list_servers = sub { ($guest, $manual) };
	my $public;
	local *main::print_json = sub { $public = $_[0]; };
	for my $grant ('*', '456') {
		local $access{'servers'} = $grant;
		do "$Bin/../servers/index-json.cgi";
		die $@ if $@;
		is_deeply($public, [map { +{id => $_->{'id'}, host => $_->{'host'}, desc => $_->{'desc'}} }
			($grant eq '*' ? ($guest, $manual) : ($manual))],
			"ACL $grant returns only permitted navigation metadata");
	}
	# A mixed forged selection must not delete even its permitted first entry.
	local $access{'servers'} = '456';
	local %in = (d => "456\0".'123', confirm => 1);
	local %text = (delete_ecannot => 'Denied');
	local *main::ReadParse = sub { };
	local *main::error_setup = sub { };
	local *main::error = sub { die "$_[0]\n"; };
	local *main::get_server = sub { $_[0] eq '123' ? $guest : $_[0] eq '456' ? $manual : undef };
	my @deleted;
	local *main::delete_server = sub { push @deleted, $_[0]; };
	local *main::webmin_log = sub { };
	local *main::redirect = sub { };
	do "$Bin/../servers/delete_servs.cgi";
	like($@, qr/Denied/, 'bulk delete refuses an inaccessible entry');
	is_deeply(\@deleted, [], 'all permissions are checked before deleting anything');
	$access{'servers'} = '*';
	$in{'d'} = 'missing';
	do "$Bin/../servers/delete_servs.cgi";
	like($@, qr/Denied/, 'bulk delete rejects missing entries even with wildcard access');
	$in{'d'} = "456\0".'123';
	do "$Bin/../servers/delete_servs.cgi";
	die $@ if $@;
	is_deeply(\@deleted, ['456', '123'], 'native wildcard grant allows deletion of both entries');
}
done_testing();
