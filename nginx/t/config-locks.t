#!/usr/bin/perl
# Config writers must use current line numbers and retain nested locks.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Cwd qw(abs_path);
use POSIX ();

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..', '..'));
my $tmp = abs_path(tempdir(CLEANUP => 1));
my $conf = "$tmp/nginx.conf";
my $included = "$tmp/servers.conf";
make_path("$tmp/config/nginx", "$tmp/var");

sub write_text
{
my ($file, $text) = @_;
open(my $fh, '>', $file) or die "$file: $!";
print $fh $text;
close($fh) or die "$file: $!";
}

write_text("$tmp/config/config", "os_type=unix\nos_version=1\n");
write_text("$tmp/config/miniserv.conf", "root=$root\n");
write_text("$tmp/config/nginx/config",
	"nginx_config=$conf\nnginx_cmd=/bin/true\n");
write_text($conf, "http {\n}\n");
$ENV{'WEBMIN_CONFIG'} = "$tmp/config";
$ENV{'WEBMIN_VAR'} = "$tmp/var";
$ENV{'FOREIGN_MODULE_NAME'} = 'nginx';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $root;
$ENV{'REMOTE_USER'} = 'root';
unshift(@INC, $root);
require "$root/nginx/nginx-lib.pl";
{ no warnings 'once'; $main::error_must_die = 1; }

sub servers
{
return join('', map {
	"    server {\n        server_name $_;\n        listen 80;\n    }\n"
} qw(alpha.invalid beta.invalid));
}

sub server
{
my ($name) = @_;
my $http = main::find('http', main::get_config());
my ($server) = grep { main::find_value('server_name', $_) eq $name }
	main::find('server', $http);
die "Missing server $name\n" if (!$server);
return $server;
}

sub add_ssl
{
my ($name) = @_;
my $server = server($name);
main::save_directive($server, 'listen',
	[{ words => [80] }, { words => [443, 'ssl'] }]);
main::save_directive($server, 'ssl_certificate', ["/$name.pem"]);
main::flush_config_file_lines();
}

foreach my $case ([0, 0], [0, 1], [1, 0], [1, 1]) {
	my ($split, $cached_lines) = @$case;
	my $name = ($split ? 'included server file' : 'single config file').
		($cached_lines ? ' with cached lines' : ' without cached lines');
	subtest $name => sub {
		write_text($conf, "http {\n".
			($split ? "    include $included;\n" : servers())."}\n");
		write_text($included, servers()) if ($split);
		main::flush_config_cache();
		my $file = $split ? $included : $conf;
		main::unflush_file_lines($file);

		# A reader caches the old config. A separate writer then inserts
		# lines into the first server before the reader edits the second.
		main::get_config();
		main::read_file_lines($file, 1) if $cached_lines;
		my $pid = fork();
		die "fork: $!" if (!defined($pid));
		if (!$pid) {
			main::lock_all_config_files();
			add_ssl('alpha.invalid');
			main::unlock_all_config_files();
			POSIX::_exit(0);
			}
		waitpid($pid, 0);
		is($?, 0, 'other writer completed');
		main::lock_all_config_files();
		add_ssl('beta.invalid');
		main::unlock_all_config_files();
		main::flush_config_cache();
		foreach my $name (qw(alpha.invalid beta.invalid)) {
			my $s = server($name);
			is_deeply([map { $_->{'words'} } main::find('listen', $s)],
				[[80], [443, 'ssl']], "$name retains both listeners once");
			is(main::find_value('ssl_certificate', $s),
				"/$name.pem", "$name retains its own certificate");
			}

		# A nested certificate update must neither discard pending writes
		# nor release the lock protecting the outer operation.
		main::lock_all_config_files();
		my $s = server('beta.invalid');
		main::save_directive($s, 'ssl_certificate_key', ['/beta.key']);
		main::lock_all_config_files($s);
		is(server('beta.invalid'), $s, 'nested lock keeps object identity');
		main::unlock_all_config_files();
		ok(-e "$conf.lock", 'nested unlock retains main config lock');
		ok(-e "$file.lock", 'nested unlock retains server file lock');
		main::flush_config_file_lines();
		main::unlock_all_config_files();
		ok(!-e "$conf.lock" && !-e "$file.lock", 'outer unlock releases locks');
		main::flush_config_cache();
		is(main::find_value('ssl_certificate_key', server('beta.invalid')),
			'/beta.key', 'nested operation preserves pending edit');
	};
}

subtest 'new includes are discovered under the main lock' => sub {
	write_text($conf, "http {\n}\n");
	main::flush_config_cache();
	main::get_config();
	write_text($conf, "http {\n    include $included;\n}\n");
	main::lock_all_config_files();
	ok(-e "$included.lock", 'newly included file is locked');
	ok(server('alpha.invalid'), 'newly included server is visible');
	main::unlock_all_config_files();
};

subtest 'locks acquired by a caller remain owned by it' => sub {
	main::lock_file($conf);
	main::lock_all_config_files();
	main::unlock_all_config_files();
	ok(-e "$conf.lock", 'pre-existing lock is retained');
	main::unlock_file($conf);
};

subtest 'included files are refreshed after waiting for their locks' => sub {
	my $extra = "$tmp/extra.conf";
	write_text($extra, "server {\n    server_name gamma.invalid;\n}\n");
	my $lock = \&main::lock_file;
	my $changed = 0;
	{
		no warnings 'redefine';
		local *main::lock_file = sub {
			# Model a direct file editor finishing after our include scan.
			if ($_[0] eq $included && !$changed++) {
				write_text($included, servers()."include $extra;\n");
				}
			return $lock->(@_);
			};
		main::lock_all_config_files();
	}
	ok(-e "$extra.lock", 'new include is locked too');
	ok(server('gamma.invalid'), 'updated include is parsed after locking');
	main::unlock_all_config_files();
};

subtest 'a parent block can span included files' => sub {
	write_text($included, "listen 80;\n");
	write_text($conf,
		"http {\n".
		"    server {\n".
		"        server_name parent.invalid;\n".
		"        include $included;\n".
		"    }\n".
		"}\n");
	main::flush_config_cache();
	my $parent = server('parent.invalid');
	is_deeply([sort(main::get_all_config_files($parent))],
		[sort($conf, $included)], 'parent spans both config files');
	main::lock_all_config_files($parent);
	ok(-e "$conf.lock" && -e "$included.lock",
		'parent lock covers both config files');
	main::unlock_all_config_files();
};

done_testing();
