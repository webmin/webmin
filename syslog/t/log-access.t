#!/usr/bin/perl
# Checks log access for users limited to some logs: BSD pipe commands are
# refused, and symlinks cannot lead to files outside the allowed logs.

use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin;

my $root = abs_path("$FindBin::Bin/../..");
require "$root/web-lib-funcs.pl";

# Load only the access functions, without module startup
foreach my $spec ([ 'syslog', [ 'can_edit_log', 'can_read_log_file',
				'readable_log_files', 'all_log_files' ] ],
		  [ 'logviewer', [ 'readable_log_files',
				   'can_read_log_file' ] ]) {
	my ($mod, $subs) = @$spec;
	open(my $lib, '<', "$root/$mod/$mod-lib.pl") or die $!;
	my $source = do { local $/; <$lib> };
	close($lib);
	foreach my $name (@$subs) {
		my ($code) = $source =~ /^(sub \Q$name\E\n\{.*?^\})/ms;
		die "Missing $name in $mod" if (!$code);
		$code =~ s/^sub \Q$name\E/sub ${mod}_$name/;
		eval "no strict; $code";
		die $@ if ($@);
		}
	}
*main::can_edit_log = \&main::syslog_can_edit_log;
*main::all_log_files = \&main::syslog_all_log_files;
*main::can_read_log_file = \&main::syslog_can_read_log_file;
*main::translate_filename = sub { return $_[0] };

my $tmp = abs_path(tempdir(CLEANUP => 1));
make_path("$tmp/app", "$tmp/private");

# write_file(path, content)
# Creates a test file with the given content
sub write_file
{
my ($path, $data) = @_;
open(my $fh, ">", $path) or die "$path: $!";
print $fh $data;
close($fh);
}

write_file("$tmp/app/app.log", "current\n");
write_file("$tmp/app/app.log.1", "old\n");
write_file("$tmp/private/secret", "secret\n");
symlink("$tmp/private/secret", "$tmp/app/app.log.2") or die "symlink: $!";
symlink("$tmp/private/secret", "$tmp/app/link.log") or die "symlink: $!";

# BSD pipes run a command, so directory limits cannot cover them
%main::access = ( 'logs' => "$tmp/app" );
$main::config{'pipe'} = 2;
ok(!main::can_edit_log({ 'pipe' => "$tmp/app/x;id>/tmp/p" }),
   'BSD pipe command is refused for limited users');
$main::config{'pipe'} = 1;
ok(main::can_edit_log({ 'pipe' => "$tmp/app/fifo" }),
   'named pipe in an allowed directory is allowed');

# Symlinks are followed before checking
ok(main::can_read_log_file("$tmp/app/app.log"), 'plain log is readable');
ok(!main::can_read_log_file("$tmp/app/link.log"),
   'symlink to a private file is refused');
%main::access = ( 'logs' => "$tmp/app/link.log" );
ok(!main::can_read_log_file("$tmp/app/link.log"),
   'symlink is refused even when listed by name');

# A listed directory replaced by a symlink does not grant its target
symlink("$tmp/private", "$tmp/app/sub") or die "symlink: $!";
%main::access = ( 'logs' => "$tmp/app/sub" );
ok(!main::can_read_log_file("$tmp/app/sub/secret"),
   'listed directory that is a symlink is not followed');
ok(!main::can_read_log_file("$tmp/private/secret"),
   'target of a listed symlink is refused');

# Rotated copies that are symlinks to other files are skipped
%main::access = ( 'logs' => "$tmp/app/app.log" );
my @files = main::syslog_readable_log_files("$tmp/app/app.log");
ok((grep { $_ eq "$tmp/app/app.log.1" } @files),
   'syslog keeps a plain rotated copy');
ok(!(grep { $_ eq "$tmp/app/app.log.2" } @files),
   'syslog skips a rotated copy that links elsewhere');
*main::can_edit_log = sub {
	return &main::syslog_can_edit_log(&main::resolve_links($_[0]));
	};
*main::can_read_log_file = \&main::logviewer_can_read_log_file;
@files = main::logviewer_readable_log_files("$tmp/app/app.log");
ok((grep { $_ eq "$tmp/app/app.log.1" } @files),
   'logviewer keeps a plain rotated copy');
ok(!(grep { $_ eq "$tmp/app/app.log.2" } @files),
   'logviewer skips a rotated copy that links elsewhere');

# Users without log limits see every rotated copy
%main::access = ( );
@files = main::syslog_readable_log_files("$tmp/app/app.log");
is(scalar(@files), 3, 'unlimited users see all rotated copies');

done_testing();
