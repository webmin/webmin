#!/usr/local/bin/perl
# Checks that package names cannot be read as rpm options.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Cwd qw(abs_path getcwd);

our (%files, %packages);
my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));

# write_text(path, content)
# Creates a test file with the given content
sub write_text
{
my ($path, $content) = @_;
open(my $fh, '>', $path) or die "open $path: $!";
print {$fh} $content;
close($fh) or die "close $path: $!";
}

# Load the real library with an isolated Webmin configuration.
my $load_dir = tempdir(CLEANUP => 1);
my $config_dir = File::Spec->catdir($load_dir, 'config');
my $var_dir = File::Spec->catdir($load_dir, 'var');
make_path(File::Spec->catdir($config_dir, 'software'), $var_dir);
write_text(File::Spec->catfile($config_dir, 'config'),
	"os_type=redhat-linux\nos_version=9\nlang=en\n");
write_text(File::Spec->catfile($config_dir, 'miniserv.conf'),
	"root=$root\nmimetypes=$root/mime.types\n");
write_text(File::Spec->catfile($config_dir, 'webmin.acl'),
	"root: software\n");
write_text(File::Spec->catfile($config_dir, 'software', 'config'),
	"package_system=rpm\nupdate_system=*\n");

my $cwd = getcwd();
my ($loaded, $load_error);
{
	local %ENV = (
		%ENV,
		WEBMIN_CONFIG  => $config_dir,
		WEBMIN_VAR     => $var_dir,
		SERVER_ROOT    => $root,
		SCRIPT_NAME    => '/software/test.cgi',
		SCRIPT_FILENAME => File::Spec->catfile($root, 'software',
						       'test.cgi'),
		REMOTE_USER     => 'root',
		BASE_REMOTE_USER => 'root',
		REQUEST_METHOD  => 'GET',
		);
	chdir(File::Spec->catdir($root, 'software'))
		or die "chdir software: $!";
	$loaded = do './software-lib.pl';
	$load_error = $@ || $!;
	chdir($cwd) or die "chdir $cwd: $!";
}
BAIL_OUT("cannot load software-lib.pl: $load_error") if !$loaded;

# Names that could be options are refused before reaching a backend
ok(!valid_package_name('--pipe=id'), 'name starting with a dash is refused');
ok(!valid_package_name("bash\nid"), 'name with a line break is refused');
ok(!valid_package_name('bash', '-1'), 'version starting with a dash is refused');
ok(valid_package_name('perl-Foo+Bar.x86_64', '1:2.3-4.el9'),
   'name with dots, plus, epoch and release is allowed');
ok(valid_package_name('python3.11'), 'name with dots is allowed');

# Capture the rpm commands that would be run
my @cmds;
{
no warnings qw(redefine once);
local *clean_language = sub { };
local *reset_environment = sub { };
local *open_execute_command = sub {
	push(@cmds, $_[1]);
	no strict 'refs';
	my $fh = $_[0];
	$fh = "main::$fh" if (!ref($fh) && $fh !~ /::/);
	open($fh, '<', \"") or die;
	return 1;
	};
local *backquote_command = sub { push(@cmds, $_[0]); return ""; };
local *backquote_logged = sub { push(@cmds, $_[0]); return ""; };

# all_end_options(label)
# Checks every captured command passes the name after the -- marker
my $all_end_options = sub {
	my ($label) = @_;
	my @bad = grep { !/ -- \\-\\-pipe/ } @cmds;
	ok(@cmds && !@bad, $label)
		or diag(join("\n", @cmds));
	@cmds = ( );
	};

check_files('--pipe=id>/tmp/p', undef);
like($cmds[0], qr/^rpm -V -- /, 'verify ends options first');
$all_end_options->('file checks end options first');
list_packages('--pipe=id');
like($cmds[0], qr/--queryformat "[^"]*" -- /,
     'package listing keeps the format before the marker');
$all_end_options->('package listing ends options first');
package_info('--pipe=id');
$all_end_options->('package info ends options first');
package_files('--pipe=id');
$all_end_options->('file listing ends options first');
delete_package('--pipe=id', { });
$all_end_options->('removal ends options first');
}

done_testing();
