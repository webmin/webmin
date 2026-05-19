#!/usr/bin/perl
# Tests for Debian-style Apache sites-available/sites-enabled handling.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Cwd qw(abs_path);

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..', '..'));
my $tmp = abs_path(tempdir(CLEANUP => 1));
my $webmin_config = File::Spec->catdir($tmp, 'webmin-config');
my $webmin_var = File::Spec->catdir($tmp, 'webmin-var');
my $apache_root = File::Spec->catdir($tmp, 'apache2');
my $available = File::Spec->catdir($apache_root, 'sites-available');
my $enabled = File::Spec->catdir($apache_root, 'sites-enabled');
my $apache_conf = File::Spec->catfile($apache_root, 'apache2.conf');

make_path($webmin_config, $webmin_var, "$webmin_config/apache",
	  "$webmin_var/apache", $apache_root, $available, $enabled);

sub write_text
{
my ($file, $text) = @_;
open(my $fh, '>', $file) || die "Failed to write $file: $!";
print $fh $text;
close($fh) || die "Failed to close $file: $!";
}

sub vhost_conf
{
my ($name, $rootdir) = @_;
my $name_line = defined($name) ? "    ServerName $name\n" : "";
return "<VirtualHost *:80>\n".
       $name_line.
       "    DocumentRoot $rootdir\n".
       "</VirtualHost>\n";
}

my $default = File::Spec->catfile($available, '000-default.conf');
my $alpha = File::Spec->catfile($available, 'alpha.conf');
my $beta = File::Spec->catfile($available, 'beta.conf');
my $charlie = File::Spec->catfile($available, 'charlie.conf');

write_text($default, vhost_conf(undef, '/srv/default'));
write_text($alpha, vhost_conf('alpha.example', '/srv/alpha'));
write_text($beta, vhost_conf('beta.example', '/srv/beta'));
write_text($charlie, vhost_conf('charlie.example', '/srv/charlie'));
write_text($apache_conf,
	"ServerRoot \"$apache_root\"\n".
	"Listen 80\n".
	"IncludeOptional $enabled/*.conf\n");

symlink($default, File::Spec->catfile($enabled, '000-default.conf')) ||
	die "Failed to symlink default: $!";
symlink($alpha, File::Spec->catfile($enabled, 'alpha.conf')) ||
	die "Failed to symlink alpha: $!";
symlink($charlie, File::Spec->catfile($enabled, 'charlie.conf')) ||
	die "Failed to symlink charlie: $!";

write_text(File::Spec->catfile($webmin_config, 'config'),
	"os_type=debian-linux\n".
	"os_version=12\n".
	"real_os_type=Debian Linux\n".
	"real_os_version=12\n");
write_text(File::Spec->catfile($webmin_config, 'miniserv.conf'),
	"root=$root\n");
write_text(File::Spec->catfile($webmin_config, 'apache', 'config'),
	"httpd_dir=$apache_root\n".
	"httpd_path=/bin/true\n".
	"httpd_conf=$apache_conf\n".
	"apachectl_path=/bin/true\n".
	"httpd_version=2.4.57\n".
	"test_apachectl=0\n".
	"test_config=1\n".
	"virt_file=$available\n".
	"link_dir=$enabled\n");

$ENV{'WEBMIN_CONFIG'} = $webmin_config;
$ENV{'WEBMIN_VAR'} = $webmin_var;
$ENV{'FOREIGN_MODULE_NAME'} = 'apache';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $root;
$ENV{'REMOTE_USER'} = 'root';

unshift(@INC, $root);
require File::Spec->catfile($root, 'apache', 'apache-lib.pl');

{
	no warnings 'once';
	$main::text{'enable_elinkdir'} = 'No enabled virtual host links directory is configured';
	$main::text{'enable_efile'} = 'Virtual host file does not exist or cannot be managed';
	$main::text{'enable_elink'} = 'Failed to create symbolic link $1 : $2';
	$main::text{'enable_eunlink'} = 'Failed to remove symbolic link $1 : $2';
	$main::text{'enable_elinkexists'} = 'The symbolic link $1 already exists';
	$main::text{'enable_etest'} = 'Apache configuration test failed after changing the virtual host file state : $1';
	$main::text{'enable_evirtualmin_disable'} = 'This Apache virtual host is managed by Virtualmin virtual server $1, which is currently $2. Site disabling should be done in Virtualmin using $3.';
	$main::text{'enable_evirtualmin_enable'} = 'This Apache virtual host is managed by Virtualmin virtual server $1, which is currently $2. Site enabling should be done in Virtualmin using $3.';
	$main::text{'enable_virtualmin_disable_label'} = 'Disable and Delete &#x21fe; Disable Virtual Server';
	$main::text{'enable_virtualmin_enable_label'} = 'Disable and Delete &#x21fe; Enable Virtual Server';
	$main::text{'index_enabled'} = 'Enabled';
	$main::text{'index_disabled'} = 'Disabled';
}

sub apache_config
{
main::flush_config_cache();
my $conf = main::get_config();
ok($conf, 'test apache config can be parsed');
return $conf;
}

sub row_names
{
return [ map {
	scalar(main::find_directive('ServerName', $_->{'virt'}->{'members'})) || ''
	} @_ ];
}

sub row_states
{
return [ map { $_->{'active'} ? 'enabled' : 'disabled' } @_ ];
}

subtest 'sites-available files are manageable and ordered' => sub {
	ok(main::can_manage_vhost_files(),
	   'sites-available/enabled dirs are manageable');
	is_deeply(
		[ main::get_vhost_available_files() ],
		[ $default, $alpha, $beta, $charlie ],
		'available files are listed in stable filename order',
	);

	my @rows = main::get_virtual_list_rows(apache_config());
	is_deeply(row_names(@rows),
		  [ '', 'alpha.example', 'beta.example', 'charlie.example' ],
		  'disabled rows stay in sites-available order');
	is_deeply(row_states(@rows),
		  [ 'enabled', 'enabled', 'disabled', 'enabled' ],
		  'row active state follows sites-enabled symlinks');
	ok(!main::can_manage_vhost_file($default),
	   'default virtual host file is not file-state manageable');
};

subtest 'disable removes only the enabled symlink' => sub {
	no warnings 'once';
	unlink($main::last_config_change_flag);
	unlink($main::last_restart_time_flag);
	main::restart_last_restart_time();
	my $old = time() - 10;
	utime($old, $old, $main::last_restart_time_flag);

	{
		no warnings 'redefine';
		local *main::test_config = sub { return undef; };
		is(main::disable_vhost_file($alpha), undef, 'disable succeeds');
	}
	ok(main::needs_config_restart(),
	   'disable marks config as needing apply');

	ok(-f $alpha, 'disable leaves the sites-available file in place');
	ok(!-e File::Spec->catfile($enabled, 'alpha.conf'),
	   'disable removes the sites-enabled symlink');

	my @rows = main::get_virtual_list_rows(apache_config());
	is_deeply(row_names(@rows),
		  [ '', 'alpha.example', 'beta.example', 'charlie.example' ],
		  'disabled row remains in the same list position');
	is_deeply(row_states(@rows),
		  [ 'enabled', 'disabled', 'disabled', 'enabled' ],
		  'disabled row status is updated');
};

subtest 'enable creates a symlink without touching the source file' => sub {
	no warnings 'once';
	unlink($main::last_config_change_flag);
	unlink($main::last_restart_time_flag);
	main::restart_last_restart_time();
	my $old = time() - 10;
	utime($old, $old, $main::last_restart_time_flag);

	{
		no warnings 'redefine';
		local *main::test_config = sub { return undef; };
		is(main::enable_vhost_file($beta), undef, 'enable succeeds');
	}
	ok(main::needs_config_restart(),
	   'enable marks config as needing apply');

	my $link = File::Spec->catfile($enabled, 'beta.conf');
	ok(-f $beta, 'enable leaves the sites-available file in place');
	ok(-l $link, 'enable creates the sites-enabled symlink');
	is(readlink($link), $beta, 'enabled symlink points to the available file');
	ok(main::vhost_file_enabled($beta), 'vhost_file_enabled sees the symlink');
};

subtest 'same-name symlink to another target is not disabled' => sub {
	my $otherdir = File::Spec->catdir($tmp, 'other-sites');
	my $other = File::Spec->catfile($otherdir, 'charlie.conf');
	my $link = File::Spec->catfile($enabled, 'charlie.conf');
	make_path($otherdir);
	write_text($other, vhost_conf('other.example', '/srv/other'));
	unlink($link) || die "Failed to remove charlie link: $!";
	symlink($other, $link) || die "Failed to symlink other charlie: $!";

	ok(!main::vhost_file_enabled($charlie),
	   'same-name symlink to another file is not considered enabled');
	{
		no warnings 'redefine';
		local *main::test_config = sub { return undef; };
		is(main::disable_vhost_file($charlie), undef, 'disable is a no-op');
	}
	ok(-l $link, 'same-name symlink to another target is preserved');
	is(readlink($link), $other, 'preserved symlink target is unchanged');
};

subtest 'file-level actions require access to every virtual host in the file' => sub {
	my $mixed = File::Spec->catfile($available, 'mixed.conf');
	write_text($mixed,
		vhost_conf('alpha.example', '/srv/mixed-alpha').
		vhost_conf('hidden.example', '/srv/mixed-hidden'));

	{
		no warnings 'once';
		local $main::access{'virts'} = 'alpha.example:80';
		ok(!main::can_manage_vhost_file($mixed),
		   'mixed-access file cannot be managed by a restricted user');
	}
	ok(main::can_manage_vhost_file($mixed),
	   'shared file can be managed when all contained vhosts are allowed');
};

subtest 'state helpers enforce allowed files and ACLs directly' => sub {
	my $outside = File::Spec->catfile($tmp, 'outside.conf');
	write_text($outside, vhost_conf('outside.example', '/srv/outside'));
	is(main::enable_vhost_file($outside),
	   'Virtual host file does not exist or cannot be managed',
	   'enable rejects files outside sites-available');

	my $mixed = File::Spec->catfile($available, 'state-mixed.conf');
	write_text($mixed,
		vhost_conf('alpha.example', '/srv/state-alpha').
		vhost_conf('hidden.example', '/srv/state-hidden'));
	{
		no warnings 'once';
		local $main::access{'virts'} = 'alpha.example:80';
		is(main::enable_vhost_file($mixed),
		   'Virtual host file does not exist or cannot be managed',
		   'enable rejects mixed-access files without relying on caller validation');
	}
};

subtest 'apache configtest failure rolls back link changes' => sub {
	my $delta = File::Spec->catfile($available, 'delta.conf');
	my $delta_link = File::Spec->catfile($enabled, 'delta.conf');
	write_text($delta, vhost_conf('delta.example', '/srv/delta'));

	{
		no warnings 'redefine';
		local *main::test_config = sub { return 'bad config'; };
		like(main::enable_vhost_file($delta), qr/bad config/,
		     'failed enable reports apache configtest output');
	}
	ok(!-e $delta_link, 'failed enable removes the new symlink');

	symlink($delta, $delta_link) || die "Failed to symlink delta: $!";
	{
		no warnings 'redefine';
		local *main::test_config = sub { return 'bad config'; };
		like(main::disable_vhost_file($delta), qr/bad config/,
		     'failed disable reports apache configtest output');
	}
	ok(-l $delta_link, 'failed disable restores the removed symlink');
	is(readlink($delta_link), $delta, 'restored symlink target is unchanged');
};

subtest 'Virtualmin-managed virtual host files cannot be toggled directly' => sub {
	my $enabled_domain = File::Spec->catfile($available, 'vm-enabled.conf');
	my $disabled_domain = File::Spec->catfile($available, 'vm-disabled.conf');
	write_text($enabled_domain,
		vhost_conf('www.vm-enabled.example', '/srv/vm-enabled'));
	write_text($disabled_domain,
		vhost_conf('vm-disabled.example', '/srv/vm-disabled'));

	{
		no warnings qw(redefine once);
		local %main::apache_virtualmin_domain_for_file_cache;
		local %main::apache_virtualmin_domain_by_name_cache;
		local *main::virtualmin_available = sub { return 1; };
		local *main::virtualmin_domain_by_name = sub {
			my ($name) = @_;
			return $name eq 'vm-enabled.example' ?
				{ 'dom' => $name, 'id' => '12345',
				  'disabled' => '' } :
			       $name eq 'vm-disabled.example' ?
				{ 'dom' => $name, 'id' => '67890',
				  'disabled' => 'web' } :
				undef;
			};

		my $disable_err =
			main::virtualmin_vhost_file_state_error($enabled_domain,
								'disable');
		my $enabled_state = main::vhost_file_state($enabled_domain);
		is($enabled_state->{'source'}, 'virtualmin',
		   'Virtualmin is the effective state source for managed files');
		ok($enabled_state->{'enabled'},
		   'Virtualmin enabled domain is reported as enabled');
		is(main::vhost_file_toggle_action($enabled_domain), 'disable',
		   'toggle action follows the Virtualmin enabled state');
		like($disable_err, qr/currently enabled/,
		     'Virtualmin state is included for enabled domains');
		like($disable_err, qr/Disable Virtual Server/,
		     'disabling directs users to Virtualmin disable action');
		like($disable_err,
		     qr{virtual-server/disable_domain\.cgi\?dom=12345},
		     'disabling links to the Virtualmin disable form');

		my $enable_err =
			main::virtualmin_vhost_file_state_error($disabled_domain,
								'enable');
		my $disabled_state = main::vhost_file_state($disabled_domain);
		is($disabled_state->{'source'}, 'virtualmin',
		   'Virtualmin remains the state source for disabled domains');
		ok(!$disabled_state->{'enabled'},
		   'Virtualmin disabled domain is reported as disabled');
		is(main::vhost_file_toggle_action($disabled_domain), 'enable',
		   'toggle action follows the Virtualmin disabled state');
		like($enable_err, qr/currently disabled/,
		     'Virtualmin state is included for disabled domains');
		like($enable_err, qr/Enable Virtual Server/,
		     'enabling directs users to Virtualmin enable action');
		like($enable_err,
		     qr{virtual-server/enable_domain\.cgi\?dom=67890},
		     'enabling links to the Virtualmin enable form');

		is(main::virtualmin_vhost_file_state_error($alpha, 'disable'),
		   undef, 'non-Virtualmin virtual host files can still be toggled');
	}
};

done_testing();
