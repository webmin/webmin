#!/usr/bin/perl
# Tests for Debian-style Nginx sites-available/sites-enabled handling.

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
my $available = File::Spec->catdir($tmp, 'sites-available');
my $enabled = File::Spec->catdir($tmp, 'sites-enabled');
my $nginx_conf = File::Spec->catfile($tmp, 'nginx.conf');

make_path($webmin_config, $webmin_var, "$webmin_config/nginx",
	  $available, $enabled);

sub write_text
{
my ($file, $text) = @_;
open(my $fh, '>', $file) || die "Failed to write $file: $!";
print $fh $text;
close($fh) || die "Failed to close $file: $!";
}

sub server_conf
{
my ($name, $body) = @_;
return "server {\n".
       "\tserver_name $name;\n".
       "\tlisten 80;\n".
       $body.
       "}\n";
}

my $alpha = File::Spec->catfile($available, 'alpha.conf');
my $beta = File::Spec->catfile($available, 'beta.conf');
my $charlie = File::Spec->catfile($available, 'charlie.conf');
my $default = File::Spec->catfile($available, 'default');

write_text($alpha, server_conf('alpha.example', "\troot /srv/alpha;\n"));
write_text($beta, server_conf('beta.example',
	"\tlocation / {\n".
	"\t\tproxy_pass http://127.0.0.1:8080;\n".
	"\t}\n"));
write_text($charlie, server_conf('charlie.example', "\troot /srv/charlie;\n"));
write_text($default, server_conf('_', "\troot /srv/default;\n"));
write_text($nginx_conf,
	"events {\n".
	"}\n".
	"http {\n".
	"\tinclude $enabled/*;\n".
	"}\n");

symlink($alpha, File::Spec->catfile($enabled, 'alpha.conf')) ||
	die "Failed to symlink alpha: $!";
symlink($charlie, File::Spec->catfile($enabled, 'charlie.conf')) ||
	die "Failed to symlink charlie: $!";
symlink($default, File::Spec->catfile($enabled, 'default')) ||
	die "Failed to symlink default: $!";

write_text(File::Spec->catfile($webmin_config, 'config'),
	"os_type=unix\n".
	"os_version=1\n".
	"real_os_type=Unix\n".
	"real_os_version=1\n");
write_text(File::Spec->catfile($webmin_config, 'miniserv.conf'),
	"root=$root\n");
write_text(File::Spec->catfile($webmin_config, 'nginx', 'config'),
	"nginx_config=$nginx_conf\n".
	"nginx_cmd=/bin/true\n".
	"add_to=$available\n".
	"add_link=$enabled\n");

$ENV{'WEBMIN_CONFIG'} = $webmin_config;
$ENV{'WEBMIN_VAR'} = $webmin_var;
$ENV{'FOREIGN_MODULE_NAME'} = 'nginx';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $root;
$ENV{'REMOTE_USER'} = 'root';

unshift(@INC, $root);
require File::Spec->catfile($root, 'nginx', 'nginx-lib.pl');

{
	no warnings 'once';
	$main::text{'server_pp'} = 'Proxy to $1';
	$main::text{'index_noroot'} = 'No root directory';
	$main::text{'index_noproxy'} = 'No proxy target';
}

sub http_config
{
main::flush_config_cache();
my $http = main::find('http', main::get_config());
ok($http, 'test nginx config has an http block');
return $http;
}

sub row_names
{
return [ map { scalar main::find_value('server_name', $_->{'server'}) } @_ ];
}

sub row_states
{
return [ map { $_->{'active'} ? 'enabled' : 'disabled' } @_ ];
}

subtest 'sites-available files are manageable and ordered' => sub {
	ok(main::can_manage_server_files(), 'sites-available/enabled dirs are manageable');
	is_deeply(
		[ main::get_add_to_files() ],
		[ $alpha, $beta, $charlie, $default ],
		'available files are listed in stable filename order',
	);

	my @rows = main::get_server_list_rows(http_config());
	is_deeply(row_names(@rows),
		  [ '_', 'alpha.example', 'beta.example', 'charlie.example' ],
		  'default site is first and other sites stay in sites-available order');
	is_deeply(row_states(@rows),
		  [ 'enabled', 'enabled', 'disabled', 'enabled' ],
		  'row active state follows sites-enabled symlinks');
};

subtest 'disable removes only the enabled symlink' => sub {
	no warnings 'once';
	unlink($main::last_config_change_flag);
	unlink($main::last_restart_time_flag);

	{
		no warnings 'redefine';
		local *main::test_config = sub { return undef; };
		is(main::disable_server_file($alpha), undef, 'disable succeeds');
	}
	ok(main::needs_config_restart(),
	   'disable marks config as needing apply');

	ok(-f $alpha, 'disable leaves the sites-available file in place');
	ok(!-e File::Spec->catfile($enabled, 'alpha.conf'),
	   'disable removes the sites-enabled symlink');

	my @rows = main::get_server_list_rows(http_config());
	is_deeply(row_names(@rows),
		  [ '_', 'alpha.example', 'beta.example', 'charlie.example' ],
		  'disabled row remains in the same list position');
	is_deeply(row_states(@rows),
		  [ 'enabled', 'disabled', 'disabled', 'enabled' ],
		  'disabled row status is updated');
};

subtest 'enable creates a symlink without touching the source file' => sub {
	no warnings 'once';
	unlink($main::last_config_change_flag);
	unlink($main::last_restart_time_flag);

	{
		no warnings 'redefine';
		local *main::test_config = sub { return undef; };
		is(main::enable_server_file($beta), undef, 'enable succeeds');
	}
	ok(main::needs_config_restart(),
	   'enable marks config as needing apply');

	my $link = File::Spec->catfile($enabled, 'beta.conf');
	ok(-f $beta, 'enable leaves the sites-available file in place');
	ok(-l $link, 'enable creates the sites-enabled symlink');
	is(readlink($link), $beta, 'enabled symlink points to the available file');
	ok(main::server_file_enabled($beta), 'server_file_enabled sees the symlink');
};

subtest 'legacy create/delete link helpers still manage symlinks' => sub {
	no warnings 'once';
	my $echo = File::Spec->catfile($available, 'echo.conf');
	my $echo_link = File::Spec->catfile($enabled, 'echo.conf');
	write_text($echo, server_conf('echo.example', "\troot /srv/echo;\n"));
	my $server = { 'file' => $echo };

	unlink($main::last_config_change_flag);
	unlink($main::last_restart_time_flag);
	main::create_server_link($server);
	ok(-l $echo_link, 'create_server_link creates expected symlink');
	is(readlink($echo_link), $echo, 'created symlink points to server file');
	ok(main::needs_config_restart(),
	   'create_server_link marks config as needing apply');

	main::update_last_restart_time();
	my $old = time() - 10;
	utime($old, $old, $main::last_restart_time_flag);
	main::delete_server_link($server);
	ok(!-e $echo_link, 'delete_server_link removes expected symlink');
	ok(-f $echo, 'delete_server_link leaves server file in place');
	ok(main::needs_config_restart(),
	   'delete_server_link marks config as needing apply');
};

subtest 'disabled server blocks can be deleted from available files' => sub {
	my $multi = File::Spec->catfile($available, 'multi.conf');
	write_text($multi,
		server_conf('one.example', "\troot /srv/one;\n").
		server_conf('two.example', "\troot /srv/two;\n"));
	my ($one_server) = grep {
		main::find_value('server_name', $_) eq 'one.example'
		} main::find_servers_in_file($multi);

	is(main::delete_servers_from_file($multi, $one_server), 1,
	   'delete_servers_from_file removes one disabled server block');
	ok(-f $multi, 'file remains when another server block is present');
	is_deeply(
		[ map { scalar main::find_value('server_name', $_) }
		  main::find_servers_in_file($multi) ],
		[ 'two.example' ],
		'only the unselected disabled server block remains');

	my ($two_server) = main::find_servers_in_file($multi);
	is(main::delete_servers_from_file($multi, $two_server), 1,
	   'delete_servers_from_file removes the last disabled server block');
	ok(!-e $multi, 'empty available file is removed after last block delete');
};

subtest 'same-name symlink to another target is not disabled' => sub {
	my $otherdir = File::Spec->catdir($tmp, 'other-sites');
	my $other = File::Spec->catfile($otherdir, 'charlie.conf');
	my $link = File::Spec->catfile($enabled, 'charlie.conf');
	make_path($otherdir);
	write_text($other, server_conf('other.example', "\troot /srv/other;\n"));
	unlink($link) || die "Failed to remove charlie link: $!";
	symlink($other, $link) || die "Failed to symlink other charlie: $!";

	ok(!main::server_file_enabled($charlie),
	   'same-name symlink to another file is not considered enabled');
	{
		no warnings 'redefine';
		local *main::test_config = sub { return undef; };
		is(main::disable_server_file($charlie), undef, 'disable is a no-op');
	}
	ok(-l $link, 'same-name symlink to another target is preserved');
	is(readlink($link), $other, 'preserved symlink target is unchanged');
};

subtest 'file-level actions require access to every server in the file' => sub {
	my $mixed = File::Spec->catfile($available, 'mixed.conf');
	write_text($mixed,
		server_conf('alpha.example', "\troot /srv/mixed-alpha;\n").
		server_conf('hidden.example', "\troot /srv/mixed-hidden;\n"));

	{
		no warnings 'once';
		local $main::access{'vhosts'} = 'alpha.example';
		ok(!main::can_manage_server_file($mixed),
		   'mixed-access file cannot be managed by a restricted user');
	}
	ok(main::can_manage_server_file($mixed),
	   'mixed-access file can be managed when vhost access is unrestricted');
};

subtest 'nginx -t failure rolls back link changes' => sub {
	my $delta = File::Spec->catfile($available, 'delta.conf');
	my $delta_link = File::Spec->catfile($enabled, 'delta.conf');
	write_text($delta, server_conf('delta.example', "\troot /srv/delta;\n"));

	{
		no warnings 'redefine';
		local *main::test_config = sub { return 'bad config'; };
		like(main::enable_server_file($delta), qr/bad config/,
		     'failed enable reports nginx -t output');
	}
	ok(!-e $delta_link, 'failed enable removes the new symlink');

	symlink($delta, $delta_link) || die "Failed to symlink delta: $!";
	{
		no warnings 'redefine';
		local *main::test_config = sub { return 'bad config'; };
		like(main::disable_server_file($delta), qr/bad config/,
		     'failed disable reports nginx -t output');
	}
	ok(-l $delta_link, 'failed disable restores the removed symlink');
	is(readlink($delta_link), $delta, 'restored symlink target is unchanged');
};

subtest 'root and proxy summaries are detected' => sub {
	my ($alpha_server) = main::find_servers_in_file($alpha);
	my ($beta_server) = main::find_servers_in_file($beta);
	my ($default_server) = main::find_servers_in_file($default);
	my $path_proxy = File::Spec->catfile($available, 'path-proxy.conf');
	write_text($path_proxy,
		"server {\n".
		"\tserver_name path.example;\n".
		"\tlisten 443 ssl http2;\n".
		"\tlocation /webmin {\n".
		"\t\tproxy_pass https://127.0.0.1:10000/;\n".
		"\t\tproxy_http_version 1.1;\n".
		"\t}\n".
		"}\n");
	my $named = File::Spec->catfile($available, 'named-proxy.conf');
	write_text($named,
		"server {\n".
		"\tserver_name named.example;\n".
		"\tlisten 80;\n".
		"\tlocation / {\n".
		"\t\ttry_files \$uri \@backend;\n".
		"\t}\n".
		"\tlocation \@backend {\n".
		"\t\tproxy_pass http://127.0.0.1:8081;\n".
		"\t}\n".
		"}\n");
	my ($path_proxy_server) = main::find_servers_in_file($path_proxy);
	my ($named_server) = main::find_servers_in_file($named);

	is_deeply([ main::server_root_proxy_state($alpha_server) ], [ 1, 0 ],
		  'root-only server state is detected');
	is(main::server_root_summary($alpha_server), '/srv/alpha',
	   'root-only server root column shows the root directory');
	is(main::server_proxy_summary($alpha_server), '<i>No proxy target</i>',
	   'root-only server proxy column shows a missing-proxy message');
	is(main::server_root_proxy_summary($alpha_server), '/srv/alpha',
	   'root-only summary shows the root directory');
	is(main::server_url($alpha_server), 'http://alpha.example/',
	   'root-only server URL uses HTTP default port');
	is(main::server_url($default_server), undef,
	   'default server has no URL link target');

	is_deeply([ main::server_root_proxy_state($beta_server) ], [ 0, 1 ],
		  'proxy-only server state is detected');
	is(main::server_root_summary($beta_server), '<i>No root directory</i>',
	   'proxy-only server root column shows a missing-root message');
	like(main::server_proxy_summary($beta_server),
	     qr{/ &#x21fe; http://127\.0\.0\.1:8080},
	     'proxy-only server proxy column shows the path and proxy target');
	like(main::server_root_proxy_summary($beta_server),
	     qr{http://127\.0\.0\.1:8080},
	     'proxy-only summary shows the proxy target');
	is(main::server_url($beta_server), 'http://beta.example/',
	   'proxy-only server URL uses HTTP default port');

	is_deeply([ main::server_root_proxy_state($path_proxy_server) ], [ 0, 1 ],
		  'non-root-location proxy state is detected');
	is(main::server_root_summary($path_proxy_server), '<i>No root directory</i>',
	   'non-root-location proxy root column shows a missing-root message');
	like(main::server_proxy_summary($path_proxy_server),
	     qr{/webmin &#x21fe; https://127\.0\.0\.1:10000/},
	     'non-root-location proxy column shows the path and proxy target');
	like(main::server_root_proxy_summary($path_proxy_server),
	     qr{https://127\.0\.0\.1:10000/},
	     'non-root-location proxy summary shows the proxy target');
	is(main::server_url($path_proxy_server), 'https://path.example/',
	   'SSL listener URL uses HTTPS default port');

	is_deeply([ main::server_root_proxy_state($named_server) ], [ 0, 1 ],
		  'named-location proxy state is detected');
	like(main::server_proxy_summary($named_server),
	     qr{\@backend &#x21fe; http://127\.0\.0\.1:8081},
	     'named-location proxy column shows the path and proxy target');
	like(main::server_root_proxy_summary($named_server),
	     qr{http://127\.0\.0\.1:8081},
	     'named-location proxy summary shows the proxy target');
	is(main::server_url($named_server), 'http://named.example/',
	   'named-location proxy URL uses HTTP default port');
};

subtest 'config change apply flag tracks pending changes' => sub {
	no warnings 'once';
	unlink($main::last_config_change_flag);
	unlink($main::last_restart_time_flag);

	ok(!main::needs_config_restart(),
	   'no apply needed when no change flag exists');
	main::update_last_config_change();
	ok(main::needs_config_restart(),
	   'apply needed after config change');
	main::update_last_restart_time();
	ok(!main::needs_config_restart(),
	   'apply not needed after config has been applied');

	my $old = time() - 10;
	utime($old, $old, $main::last_restart_time_flag);
	main::update_last_config_change();
	ok(main::needs_config_restart(),
	   'apply needed when config change is newer than last apply');
};

subtest 'manual edit ACL is separately configurable' => sub {
	no warnings 'once';
	{
		local %main::access = ( 'global' => 1 );
		ok(main::can_edit_manual_config(),
		   'manual edit defaults to global ACL for existing users');
	}
	{
		local %main::access = ( 'global' => 0 );
		ok(!main::can_edit_manual_config(),
		   'manual edit is denied when global ACL default is denied');
	}
	{
		local %main::access = ( 'global' => 1, 'manual' => 0 );
		ok(!main::can_edit_manual_config(),
		   'manual edit can be disabled for global users');
	}
	{
		local %main::access = ( 'global' => 0, 'manual' => 1 );
		ok(main::can_edit_manual_config(),
		   'manual edit can be explicitly enabled');
	}
};

subtest 'manual edit files respect vhost ACL' => sub {
	my $single = File::Spec->catfile($available, 'manual-single.conf');
	my $shared = File::Spec->catfile($available, 'manual-shared.conf');
	write_text($single,
		server_conf('single.example', "\troot /srv/single;\n"));
	write_text($shared,
		server_conf('single.example', "\troot /srv/shared-single;\n").
		server_conf('other.example', "\troot /srv/shared-other;\n"));
	symlink($single, File::Spec->catfile($enabled, 'manual-single.conf')) ||
		die "Failed to symlink manual-single: $!";
	symlink($shared, File::Spec->catfile($enabled, 'manual-shared.conf')) ||
		die "Failed to symlink manual-shared: $!";
	main::flush_config_cache();

	{
		local %main::access = ( 'manual' => 1,
					'vhosts' => 'single.example' );
		ok(main::can_edit_manual_file($single),
		   'restricted user can manually edit their own single-server file');
		ok(!main::can_edit_manual_file($shared),
		   'restricted user cannot manually edit a shared server file');
		is_deeply(
			[ grep { $_ eq $single || $_ eq $shared }
			  main::get_manual_config_files() ],
			[ $single ],
			'manual file list excludes shared files for restricted users');
	}
	{
		local %main::access = ( 'manual' => 1 );
		ok(main::can_edit_manual_file($shared),
		   'unrestricted user can manually edit shared server files');
	}
};

done_testing();
