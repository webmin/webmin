#!/usr/bin/perl
# Bundled modules must load outside MiniServ, even after a directory change.
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use Cwd qw(abs_path getcwd);
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Copy qw(copy);
use IPC::Open3;
use Symbol qw(gensym);

my $root = abs_path("$Bin/..");
my $work = abs_path(tempdir(CLEANUP => 1));
my $parser = 'vendor_perl/Data/Dumper/Parser.pm';
# A separate copy proves that an explicit LIBROOT still takes precedence.
make_path("$work/override/vendor_perl/Data/Dumper");
copy("$root/$parser", "$work/override/$parser") or die $!;
my $code = <<'PERL';
use WebminCore;
# Shared TLS helpers must be available to modules using the core API.
for my $name (qw(init_ssl_context init_ssl_connection connect_ssl_connection
		read_ssl_connection write_ssl_connection rpc_tls_context
		rpc_tls_start rpc_tls_fingerprint rpc_tls_send_file
		rpc_tls_receive_file rpc_tls_close)) {
	die "TLS helper $name was not exported\n" unless main->can($name);
	}
# Relative imports must still work when a caller later changes directories.
chdir($ARGV[0]) or die $!;
my $value = unserialise_variable(q{$VAR1 = { 'status' => 1, 'rv' => 'ok' };});
die "RPC reply did not parse\n"
	unless ref($value) eq 'HASH' && $value->{'status'} == 1 &&
	       $value->{'rv'} eq 'ok';
print $INC{'Data/Dumper/Parser.pm'};
PERL

for my $case (
	[ 'unset LIBROOT', undef, $work, $root, $root ],
	[ 'empty LIBROOT', '', $work, $root, $root ],
	[ 'relative module path', undef, "$root/servers", '..', $root ],
	[ 'explicit LIBROOT', "$work/override", $work, $root,
	  "$work/override" ]) {
	# Use fresh interpreters so earlier imports cannot hide a missing path.
	my ($name, $libroot, $cwd, $include, $expected) = @$case;
	local @ENV{qw(LIBROOT PERLLIB PERL5LIB PERL5OPT)};
	delete @ENV{qw(LIBROOT PERLLIB PERL5LIB PERL5OPT)};
	$ENV{'LIBROOT'} = $libroot if (defined($libroot));
	my $original = getcwd();
	chdir($cwd) or die $!;
	my $error = gensym();
	my $pid = open3(my $input, my $output, $error,
			$^X, "-I$include", '-e', $code, $work);
	chdir($original) or die $!;
	close($input);
	local $/;
	my $stdout = <$output>;
	my $stderr = <$error>;
	waitpid($pid, 0);
	# Require a parsed reply from the intended installation, without errors.
	is($?, 0, "$name: RPC reply parses");
	is($stdout, "$expected/$parser", "$name: intended parser loads");
	is($stderr, '', "$name: no loading errors");
	}

# Framed CGIs load the theme into the package that imported WebminCore.
{
	package FramedCGI;
	local @INC = ($root, @INC);
	require WebminCore;
	WebminCore->import();
	require "gray-theme/theme.pl";
	my $icons = ui_icons();
	::is($icons->{'alert'}->{'danger'}, 'x-circle', 'alert types map to SVG icon names');
	::is($icons->{'fa'}->{'fa-lock'}, 'shield', 'Font Awesome classes map to SVG icon names');
	::like(theme_ui_alert('Notice', 'info', 'fa-lock'), qr/ui_svg_icon_shield/,
		'Framed can render alerts when a CGI loads the theme directly');
	{
		no warnings 'once';
		local *WebminCore::theme_ui_icons = sub {
			return { 'alert' => { 'info' => 'clock' }, 'fa' => { } };
			};
		::like(ui_alert_icon('info', 'fa-unknown'), qr/ui_svg_icon_clock/,
			'an unknown class falls back to the themed alert icon');
	}
}

done_testing();
