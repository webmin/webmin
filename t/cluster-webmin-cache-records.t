#!/usr/bin/perl
# Check that the cluster modules skip or clean unusual records from managed
# servers instead of refusing the whole host, while keeping cache paths safe.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;
use File::Temp qw(tempdir);

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";

# load_subs(package, file, sub-name, ...)
# Compiles named subs from a module library into their own package, so the
# real cache code runs without initializing the module.
sub load_subs
{
my ($pkg, $file, @subs) = @_;
open(my $fh, '<', "$root/$file") or die "$file: $!";
my $code = do { local $/; <$fh> };
close($fh);
foreach my $sub (@subs) {
	$code =~ /(^sub \Q$sub\E\n\{.*?^\})/ms or die "Missing $sub in $file";
	eval "package $pkg; no strict; no warnings; $1";
	die $@ if $@;
	}
no strict 'refs';
foreach my $f ('write_file', 'read_file') {
	*{"${pkg}::$f"} = \&{"main::$f"};
	}
*{"${pkg}::error"} = sub { die join(' ', @_)."\n" };
}

# read_cache(file)
# Returns the key/value pairs stored in one cache file.
sub read_cache
{
my %h;
main::read_file($_[0], \%h) or return;
return \%h;
}

# list_dir(dir)
# Returns the sorted file names in a directory.
sub list_dir
{
opendir(my $dh, $_[0]) or return ();
my @rv = sort grep { !/^\.\.?$/ } readdir($dh);
closedir($dh);
return @rv;
}

load_subs('servers', 'servers/servers-lib.pl', 'cache_path_component');
load_subs('cw', 'cluster-webmin/cluster-webmin-lib.pl',
	  'save_webmin_host', 'clean_cache_record');
load_subs('cu', 'cluster-usermin/cluster-usermin-lib.pl',
	  'save_usermin_host', 'clean_cache_record');
load_subs('ca', 'cluster-useradmin/cluster-useradmin-lib.pl',
	  'save_useradmin_host', 'clean_cache_record');

# Records that one managed server could return
my @modules = (
	{ 'dir' => 'good-module', 'desc' => 'Good',
	  'desc_sr@latin' => 'Dobar', 'third party+key' => 'kept' },
	{ 'dir' => 'trailing', 'desc' => "Trailing newline\n" },
	{ 'dir' => 'inject', 'desc' => "x\nversion=evil",
	  "bad\nkey" => 'dropped', 'bad=key' => 'dropped' },
	{ 'dir' => '../../escape', 'desc' => 'Path traversal' },
	{ 'dir' => 'a/b', 'desc' => 'Slash' },
	{ 'dir' => "nl\n", 'desc' => 'Newline in name' },
	'not a hash',
	);

subtest 'cluster-webmin keeps good records and skips bad names' => sub {
	my $dir = tempdir('cluster-cache.XXXXXX', DIR => '/tmp', CLEANUP => 1);
	local $cw::module_config_directory = $dir;
	my $host = {
		'id' => 7,
		'version' => "2.500\n",
		"real os\nkey" => 'dropped',
		'modules' => [ @modules ],
		'themes' => [ { 'dir' => 'theme-one', 'desc' => "Theme\n" } ],
		'users' => [
			{ 'name' => 'admin', 'modules' => [ 'acl', "x\ny" ],
			  'ownmods' => [ ], 'olds' => [ ],
			  'real' => "Ad'min\n" },
			{ 'name' => '../../root', 'modules' => [ ] },
			],
		'groups' => [
			{ 'name' => 'staff', 'modules' => [ 'acl' ],
			  'ownmods' => [ ], 'members' => [ 'admin' ] },
			],
		};
	my $ok = eval { cw::save_webmin_host($host); 1 };
	ok($ok, 'unusual records do not fail the host') or diag($@);
	is_deeply([ list_dir("$dir/hosts/7") ],
		  [ 'admin.user', 'good-module.mod', 'inject.mod',
		    'staff.group', 'theme-one.theme', 'trailing.mod',
		    'webmin' ],
		  'only records with safe names are cached');
	ok(!-e "$dir/escape.mod" && !-e "$dir/hosts/escape.mod",
	   'path traversal name is not written');

	my $good = read_cache("$dir/hosts/7/good-module.mod");
	is($good->{'desc_sr@latin'}, 'Dobar', 'key with @ is kept');
	is($good->{'third party+key'}, 'kept', 'key with space and + is kept');
	is(read_cache("$dir/hosts/7/trailing.mod")->{'desc'},
	   'Trailing newline', 'trailing newline is removed from a value');
	my $inject = read_cache("$dir/hosts/7/inject.mod");
	is($inject->{'desc'}, 'x version=evil', 'line break becomes a space');
	ok(!exists($inject->{'version'}), 'value cannot add a new key');
	ok(!grep({ /bad/ } keys %$inject),
	   'keys with = or line breaks are dropped');
	my $user = read_cache("$dir/hosts/7/admin.user");
	is($user->{'modules'}, 'acl x y',
	   'module lists are joined on one line');
	is($user->{'real'}, "Ad'min", 'apostrophe in a real name is kept');
	my $webmin = read_cache("$dir/hosts/7/webmin");
	is($webmin->{'version'}, '2.500', 'host details are cleaned');
	ok(!grep({ /real os/ } keys %$webmin), 'bad host keys are dropped');
	};

subtest 'cluster-webmin still rejects an unsafe host ID' => sub {
	my $dir = tempdir('cluster-cache.XXXXXX', DIR => '/tmp', CLEANUP => 1);
	local $cw::module_config_directory = $dir;
	my $ok = eval { cw::save_webmin_host({ 'id' => '../x' }); 1 };
	ok(!$ok, 'host ID with a path is refused');
	ok(!-e "$dir/x", 'nothing is written outside the hosts directory');
	};

subtest 'cluster-usermin keeps good records and skips bad names' => sub {
	my $dir = tempdir('cluster-cache.XXXXXX', DIR => '/tmp', CLEANUP => 1);
	local $cu::module_config_directory = $dir;
	my $host = { 'id' => 3, 'version' => "1.900\n",
		     'modules' => [ @modules ], 'themes' => [ ] };
	my $ok = eval { cu::save_usermin_host($host); 1 };
	ok($ok, 'unusual records do not fail the host') or diag($@);
	is_deeply([ list_dir("$dir/hosts/3") ],
		  [ 'good-module.mod', 'inject.mod', 'trailing.mod',
		    'usermin' ],
		  'only records with safe names are cached');
	is(read_cache("$dir/hosts/3/usermin")->{'version'}, '1.900',
	   'host details are cleaned');
	};

subtest 'cluster-useradmin keeps macOS style records' => sub {
	my $dir = tempdir('cluster-cache.XXXXXX', DIR => '/tmp', CLEANUP => 1);
	local $ca::module_config_directory = $dir;
	my $host = {
		'id' => 5,
		'users' => [
			{ 'user' => 'jane', 'real' => "Jane O'Neil\n",
			  'home' => "/Users/jane\n", 'shell' => '/bin/zsh' },
			{ 'user' => 'jos', 'real' => "Jos\x{e9} M\x{fc}ller" },
			{ 'user' => '../../etc/cron.d/x', 'real' => 'Bad' },
			{ 'user' => '', 'real' => 'Empty' },
			],
		'groups' => [
			{ 'group' => 'staff', 'members' => 'jane,jos' },
			{ 'group' => '..', 'members' => '' },
			],
		};
	my $ok = eval { ca::save_useradmin_host($host); 1 };
	ok($ok, 'unusual records do not fail the host') or diag($@);
	is_deeply([ list_dir("$dir/hosts/5") ],
		  [ 'jane.user', 'jos.user', 'staff.group' ],
		  'only records with safe names are cached');
	my $jane = read_cache("$dir/hosts/5/jane.user");
	is($jane->{'real'}, "Jane O'Neil",
	   'trailing newline from dscl is removed');
	is($jane->{'home'}, '/Users/jane', 'home directory is kept');
	ok(!-e "$dir/etc", 'path traversal user is not written');

	# A second refresh removes cache files for records that went away
	$host->{'users'} = [ { 'user' => 'jos', 'real' => 'Jos' } ];
	ca::save_useradmin_host($host);
	is_deeply([ list_dir("$dir/hosts/5") ], [ 'jos.user', 'staff.group' ],
		  'stale records are removed on the next save');
	};

done_testing();
