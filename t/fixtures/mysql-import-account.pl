#!/usr/bin/perl
# Manage the loopback-only account used by mysql-import-live.py on a test VM.
use strict;
use warnings;
use JSON::PP;
my ($root, $statefile, $action) = @ARGV;
$ENV{'WEBMIN_CONFIG'} = '/etc/webmin';
$ENV{'WEBMIN_VAR'} = '/var/webmin';
$ENV{'MINISERV_CONFIG'} = '/etc/webmin/miniserv.conf';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $root;
$ENV{'FOREIGN_MODULE_NAME'} = '';
push(@INC, $root);
chdir($root) or die $!;
require WebminCore;
WebminCore->import();
$main::webmin_script_type = 'cmd';
$main::no_referers_check = 1;
&main::init_config();
&main::foreign_require('acl', 'acl-lib.pl');
open(my $fh, '<', $statefile) or die $!;
my $state = decode_json(do { local $/; <$fh> });
close($fh);
my $user = $state->{'user'};
$user =~ /^csvtest_[a-f0-9]+$/ or die 'Unexpected fixture username';
if ($action eq 'create') {
	die 'Fixture already exists' if (&acl::list_users([$user]));
	&acl::create_user({ name => $user,
		pass => &acl::encrypt_password($state->{'password'}),
		modules => ['mysql'], allow => '127.0.0.1', lang => 'en' });
	}
if ($action eq 'create' || $action eq 'update') {
	&main::save_module_acl({ dbs => $state->{'db'}, edonly => 0,
		user => $state->{'db'}, pass => $state->{'password'},
		buser => $state->{'buser'}, bpath => $state->{'directory'} },
		$user, 'mysql', 1);
	}
elsif ($action eq 'delete') {
	&acl::delete_user($user);
	}
else { die 'Unknown action'; }
&main::reload_miniserv();
print "Fixture account $action OK\n";
