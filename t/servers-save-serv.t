#!/usr/bin/perl
# Check server form validation, forced options and saved password handling
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

# Hosts and types must be safe, known values.
like(&save({ %base, host => 'x"onmouseover="alert(1)' }),
     qr/\Q$text{'save_ehost'}\E/, 'markup in a host is refused');
is(&save({ %base, host => '2001:db8::1' }), '', 'IPv6 hosts are accepted');
is(&save({ %base, host => 'web-1.example_lab.test' }), '',
   'hostnames with dots, dashes and underscores are accepted');
like(&save({ %base, type => 'x"><script>' }),
     qr/\Q$text{'save_etype'}\E/, 'unknown types are refused');
is(&save({ %base, type => 'ubuntu' }), '', 'known types are accepted');
$record->{'type'} = 'legacy';
is(&save({ %base, type => 'legacy' }), '', 'an unchanged saved type is kept');
$record->{'type'} = 'debian';

# The stored password is kept only for the same destination.
is(&save({ %base, mode => 1, wuser => 'admin', wpass => '' }), '',
   'empty password keeps the saved one');
is($saved->{'pass'}, 'stored-secret', 'saved password is unchanged');
like(&save({ %base, host => 'new.test', mode => 1, wuser => 'admin',
	     wpass => '' }),
     qr/\Q$text{'save_epass'}\E/, 'a new host needs the password again');
is(&save({ %base, mode => 1, wuser => 'admin', wpass => 'new-secret' }), '',
   'a new password can be entered');
is($saved->{'pass'}, 'new-secret', 'entered password is saved');

done_testing();
