#!/usr/bin/perl
# Exercise subgroup creation through the real handler and ACL storage routines.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
BEGIN {
	eval { require DBI; require DBD::SQLite; 1 }
		or plan skip_all => 'DBI and DBD::SQLite are required';
}
require "$FindBin::Bin/../web-lib-funcs.pl";
our ($config_directory, $base_remote_user, %in, %access);
$base_remote_user = 'admin';
my ($db, $proto);

# Keep configuration, SQL connections and module discovery in the fixture.
*main::get_userdb_string = sub { return $proto ? "$proto://fixture" : ''; };
*main::get_miniserv_config = sub {
	%{$_[0]} = (userdb => get_userdb_string());
	};
*main::connect_userdb = sub { return ($db, $proto); };
*main::disconnect_userdb = sub {};
*main::module_root_directory = sub { return $config_directory; };
*main::get_module_preferences_acl = sub { return undef; };
*main::list_modules = sub { return ('example'); };
*main::list_users = sub { return (); };
*main::error = sub { die join('', @_)."\n"; };
*main::text = sub { return join(': ', @_); };

# Supply parsed forms and skip daemon reloads, logging and CGI output.
$INC{'./acl-lib.pl'} = 1;
*main::ReadParse = sub {};
*main::error_setup = sub {};
*main::reload_miniserv = sub {};
*main::webmin_log = sub {};
*main::redirect = sub { return 1; };

# load_routine(file, name)
# Load production routines without initializing the workstation's Webmin.
sub load_routine
{
my ($file, $name) = @_;
open(my $fh, '<', "$FindBin::Bin/../$file") or die $!;
local $/;
my $source = <$fh>;
$source =~ /^(sub \Q$name\E\n\{.*?)(?=^=head2|\z)/ms or die "Missing $name";
eval "no strict; $1";
die $@ if $@;
}
load_routine('web-lib.pl', 'unique');
load_routine('acl/acl-lib.pl', $_) for qw(
	create_group modify_group list_groups get_group group_line update_members
	copy_acl_files copy_group_acl_files copy_group_user_acl_files);

# Use SQLite to execute the statements shared by MySQL and PostgreSQL.
# Local storage also checks that moving creation preserves existing behavior.
for my $backend ('', 'mysql', 'postgresql') {
	$proto = $backend;
	my $label = $proto || 'files';
	$config_directory = tempdir(TMPDIR => 1, CLEANUP => 1);
	$db = DBI->connect('dbi:SQLite:dbname=:memory:', '', '',
		{RaiseError => 1, PrintError => 0, AutoCommit => 1});
	for my $kind ('user', 'group') {
		$db->do("create table webmin_$kind ".
			"(id integer primary key, name text, description text)");
		$db->do("create table webmin_${kind}_attr ".
			"(id integer, attr text, value text)");
		$db->do("create table webmin_${kind}_acl ".
			"(id integer, module text, attr text, value text, ".
			"primary key(id,module,attr))");
		}

	# Distinct parent and clone ACLs expose changes to their copy order.
	for my $name ('parent', 'source') {
		create_group({name => $name, modules => ['example'], members => []});
		save_group_module_acl({fileunix => $name,
			rpc => $name eq 'source' ? 1 : 0},
			$name, '', 1);
		save_group_module_acl({fixture => $name}, $name, 'example', 1);
		}
	%access = (groups => 1, acl => 0, gassign => '*');
	for my $case (
		['child', 'parent', '', 'parent', 0],
		['cloned', 'parent', 'source', 'source', 1],
		['standalone', '', 'source', 'source', 1]) {
		my ($name, $parent, $clone, $expected, $rpc) = @$case;
		%in = (name => $name, desc => 'Fixture', group => $parent,
			clone => $clone, mod => 'example');
		do "$FindBin::Bin/../acl/save_group.cgi";
		die $@ if $@;
		# Inspect persisted membership as a subsequent request would.
		unflush_file_lines("$config_directory/webmin.groups");
		ok(get_group($name), "$label creates $name");
		my %global = get_group_module_acl($name, '', 1);
		is_deeply(\%global, {fileunix => $expected, rpc => $rpc},
			"$label $name global ACL");
		my %module_acl = get_group_module_acl($name, 'example', 1);
		is($module_acl{fixture}, $expected, "$label $name module ACL");
		if ($proto) {
			# SQL-backed groups must not leave an ignored local policy.
			ok(!-e "$config_directory/$name.gacl",
				"$label $name has no stray global ACL file");
			}

		# New members must inherit the saved global and module permissions.
		my $member = $name.'_member';
		if ($proto) {
			# Give the fixture user a database identity before copying ACLs.
			$db->do('insert into webmin_user (name) values (?)',
				undef, $member);
			}
		copy_group_user_acl_files($name, $member, ['', 'example']);
		my %member_global = get_module_acl($member, '', 1, 1);
		is_deeply(\%member_global, {fileunix => $expected, rpc => $rpc},
			"$label $name member inherits global ACL");
		my %member_module = get_module_acl($member, 'example', 1, 1);
		is($member_module{fixture}, $expected,
			"$label $name member inherits module ACL");
		}
	$db->disconnect();
	}
done_testing();
