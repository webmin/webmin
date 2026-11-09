#!/usr/bin/perl
# Check group ACL writes, copies and deletion against cached reads.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
require "$FindBin::Bin/../web-lib-funcs.pl";

# Keep all configuration and file operations inside the temporary fixture.
our $config_directory = tempdir(TMPDIR => 1, CLEANUP => 1);
*main::get_userdb_string = sub { return ''; };
*main::get_miniserv_config = sub { %{$_[0]} = (); };
*main::module_root_directory = sub { return $config_directory; };
*main::list_modules = sub { return ('example'); };
*main::error = sub { die join('', @_)."\n"; };

# Load only the group helpers, without initializing Webmin on the host.
open(my $fh, '<', "$FindBin::Bin/../acl/acl-lib.pl") or die $!;
my $source = do { local $/; <$fh> };
close($fh);
foreach my $name (qw(create_group delete_group group_line copy_acl_files)) {
	$source =~ /^(sub \Q$name\E\n\{.*?)(?=^=head2|\z)/ms
		or die "Missing $name";
	eval "no strict; $1";
	die $@ if $@;
	}

create_group({ name => 'target', modules => [ 'example' ], members => [] });
foreach my $module ('', 'example') {
	my $label = $module eq '' ? 'global' : 'module';
	my $file = $module eq '' ? "$config_directory/target.gacl" :
		"$config_directory/$module/target.gacl";
	# Saving after a missing read must clear the cached absence.
	my %missing = get_group_module_acl('target', $module, 1);
	is_deeply(\%missing, {}, "$label: initially missing");
	save_group_module_acl({ rpc => 1 }, 'target', $module, 1);
	my %saved = get_group_module_acl('target', $module, 1);
	is_deeply(\%saved, { rpc => 1 }, "$label: saved ACL is readable");

	# Updating a previously read ACL must refresh its cached contents.
	save_group_module_acl({ rpc => 0 }, 'target', $module, 1);
	my %updated = get_group_module_acl('target', $module, 1);
	is_deeply(\%updated, { rpc => 0 }, "$label: save refreshes cache");

	# Copies must replace cached destination permissions, including old keys.
	save_group_module_acl({ fileunix => 'copied' }, 'source', $module, 1);
	copy_acl_files('source', 'target', [ $module ], 'group', 'group');
	my %copied = get_group_module_acl('target', $module, 1);
	is_deeply(\%copied, { fileunix => 'copied' },
		"$label: copy replaces cached ACL");

	# A direct read through the normal filename must share the same cache.
	my %direct;
	read_file_cached($file, \%direct);
	save_group_module_acl({ rpc => 1 }, 'target', $module, 1);
	my %refreshed;
	read_file_cached($file, \%refreshed);
	is_deeply(\%refreshed, { rpc => 1 },
		"$label: save refreshes the normal path's cache");
	}

# Deleting and recreating a group must not revive cached global or module ACLs.
delete_group('target');
foreach my $module ('', 'example') {
	my $label = $module eq '' ? 'global' : 'module';
	my %deleted = get_group_module_acl('target', $module, 1);
	is_deeply(\%deleted, {}, "$label: deleted ACL is no longer cached");
	}
create_group({ name => 'target', modules => [ 'example' ], members => [] });
foreach my $module ('', 'example') {
	my $label = $module eq '' ? 'global' : 'module';
	my %recreated = get_group_module_acl('target', $module, 1);
	is_deeply(\%recreated, {}, "$label: recreated group has no old ACL");
	}
done_testing();
