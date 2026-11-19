#!/usr/bin/perl
# Check forced server options
# without writing the server list or contacting remote hosts.
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/..";
use WebminCore;
use Test::More;
our (%access, %in, %config, %text);
# Load server helpers without reading installed Webmin configuration.
{
	no warnings qw(redefine once);
	# import([args...]) suppresses module initialization on the second load.
	local *WebminCore::import = sub { };
	# init_config([args...]) leaves this fixture's configuration in memory.
	local *main::init_config = sub { };
	# get_module_acl() grants access to the synthetic server records.
	local *main::get_module_acl = sub { (servers => '*', links => 1) };
	require "$Bin/../servers/servers-lib.pl";
}
open(my $lang, '<', "$Bin/../servers/lang/en") or die $!;
while (<$lang>) {
	$text{$1} = $2 if (/^(\S+)=(.*)$/);
	}
close($lang);

no warnings qw(redefine once);
my ($record, $saved);
# ReadParse() keeps the inputs supplied by each case.
*main::ReadParse = sub { };
# error_setup(message) suppresses CGI error-page configuration.
*main::error_setup = sub { };
# error(message) exposes refusals as exceptions.
*main::error = sub { die "$_[0]\n" };
# to_ipaddress(host) and to_ip6address(host) resolve without DNS.
*main::to_ipaddress = sub { $_[0] =~ /:/ ? undef : '192.0.2.1' };
*main::to_ip6address = sub { $_[0] =~ /:/ ? $_[0] : undef };
# webmin_log(args...) and redirect(url) have no side effects here.
*main::webmin_log = *main::redirect = sub { };
# get_server(id) returns a copy of the fixture record.
*main::get_server = sub { +{ %$record } };
# save_server(record) captures the record without writing a file.
*main::save_server = sub { $saved = { %{$_[0]} } };
local $INC{'./servers-lib.pl'} = 1;

# save(inputs, [acl]) runs save_serv.cgi and returns its error, if any.
sub save
{
my ($inputs, $acl) = @_;
local %access = ( edit => 1, add => 1, pass => 1, servers => '*',
		  %{$acl || { }} );
local %in = %$inputs;
$saved = undef;
do "$Bin/../servers/save_serv.cgi";
return $@;
}

$record = { id => 7, host => 'old.test', port => 10000, type => 'debian',
	    user => 'admin', pass => 'stored-secret', fast => 1,
	    group => "red\tblue" };
my %base = ( id => 7, host => 'old.test', port => 10000, ssl => 1,
	     type => 'debian', mode => 0, fast => 1 );

# Options an admin cannot change keep their saved values.
is(&save({ %base, type => 'windows', mode => 0, fast => 0,
	   wuser => 'admin', wpass => $record->{'pass'}, group => 'green',
	   newgroup => 'admins' },
	 { forcetype => 1, forcelink => 1, forcefast => 1,
	   forcegroup => 1 }), '', 'forced options save');
is($saved->{'type'}, 'debian', 'forced type is kept');
is($saved->{'user'}, 'admin', 'forced login mode is kept');
is($saved->{'pass'}, 'stored-secret', 'forced login keeps the password');
is($saved->{'fast'}, 1, 'forced fast RPC mode is kept');
is($saved->{'group'}, "red\tblue", 'forced groups are kept');
like(&save({ %base, mode => 3 }, { pass => 0 }),
     qr/\Q$text{'edit_ecannot'}\E/,
     'same-login mode needs password access');

done_testing();
