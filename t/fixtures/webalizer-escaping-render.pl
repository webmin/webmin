#!/usr/bin/perl
# Render Webalizer pages with real UI helpers and private log/config fixtures.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use JSON::PP;
use File::Temp qw(tempdir);

# Let a CGI finish without terminating the fixture before its JSON is returned.
BEGIN { *CORE::GLOBAL::exit = sub { die "FIXTURE_EXIT\n" }; }

my ($root, $page, $json) = @ARGV;
my $case = decode_json($json);
my $tmp = tempdir('webmin-webalizer.XXXXXX', DIR => '/tmp', CLEANUP => 1);
require "$root/web-lib-funcs.pl";
require "$root/ui-lib.pl";
$INC{'./webalizer-lib.pl'} = 1;
for my $file ("$root/lang/en", "$root/webalizer/lang/en") {
	open(my $lang, '<', $file) or die $!;
	while (<$lang>) {
		$main::text{$1} = $2 if /^(\S+)=(.*)$/;
		}
	close($lang);
	}

# Load file/ACL helpers without module initialization or service discovery.
open(my $lib, '<', "$root/webalizer/webalizer-lib.pl") or die $!;
my $code = do { local $/; <$lib> };
close($lib);
for my $sub (qw(can_edit_log config_file_name log_config_name get_log_config
		 all_log_files find find_value generate_report)) {
	$code =~ /(^sub \Q$sub\E\n\{.*?^\})/ms or die "Missing $sub";
	eval 'no strict; no warnings; '.$1;
	die $@ if $@;
	}
my $generate_report = \&main::generate_report;
my $file = "$tmp/$case->{'name'}";
my $report_dir = "$tmp/report-$case->{'name'}";
$main::module_config_directory = "$tmp/config";
$main::module_name = 'webalizer';
mkdir($main::module_config_directory) or die $!;
mkdir($report_dir) or die $!;

# write_fixture(path, data) writes only files in this test's temporary directory.
sub write_fixture
{
my ($path, $data) = @_;
open(my $out, '>', $path) or die "$path: $!";
print $out $data;
close($out) or die $!;
}

write_fixture($file, "Fixture log\n") unless $case->{'missing'};
my $rotated = $file.($case->{'rotation'} // '.1');
write_fixture($rotated, "Older log\n") unless $case->{'missing'};
write_fixture(main::log_config_name($file), "dir=$report_dir\nuser=root\ntype=1\n")
	unless $case->{'no_config'};
write_fixture("$report_dir/index.html", "<TITLE>Fixture</TITLE>\n<BODY>\nReport body\n</BODY>\n")
	unless $case->{'no_report'};

%main::in = (file => $file, type => 1, custom => 1, run => 1);
%main::access = (dir => '/', user => 'root', global => 1,
	%{$case->{'access'} || {}});
%main::config = (webalizer => 'fixture-only', webalizer_conf => "$root/webalizer/config");
# PATH_INFO is already decoded once by the web server for normal report links.
$ENV{'PATH_INFO'} = '/'.main::urlize($file).'/index.html';
if ($case->{'raw_quote'}) {
	$ENV{'PATH_INFO'} =~ s/%22/"/g;
	}
if ($case->{'decoded_path'}) {
	$ENV{'PATH_INFO'} = "$file/index.html";
	}

# Keep HTML rendering and file reads real; isolate authentication and services.
*main::ReadParse = *main::foreign_require = *main::load_theme_library = sub { };
*main::error = sub { die join(' ', @_)."\n" };
*main::error_setup = *main::webmin_log = sub { };
*main::ui_print_header = sub { print main::ui_post_header($_[0]) };
*main::ui_print_unbuffered_header = \&main::ui_print_header;
*main::get_module_variable = sub { return \%main::text };
*main::get_module_name = sub { 'webalizer' };
*main::get_module_info = sub { return () };
*main::get_webprefix = *main::file_chooser_button = *main::help_search_link = sub { '' };
*main::eval_as_unix_user = sub { $_[1]->() };
*main::get_config = sub { [] };
*main::has_command = sub { 1 };
*main::get_webalizer_version = sub { '2.23' };
*main::get_webalizer_prog = sub { 'webalizer' };
*main::get_all_logs = sub { ({ file => $file, type => 1, custom => 1 }) };
*cron::get_times_input = sub { '' };

# Exercise the real missing-file branch, but never run Webalizer or change cron.
my @reports;
*main::generate_report = sub {
	push(@reports, [ $_[0], $_[2] ]);
	return $generate_report->(@_) if $case->{'missing'};
	my $out = $_[1];
	print $out "Fixture report output\n";
	return $case->{'failed'} ? 0 : 1;
	};
*main::open_execute_command = *main::lock_file = *main::save_log_config =
	*cron::list_cron_jobs = sub { die "Unexpected backend operation\n" };

my ($html, $error) = ('', '');
open(my $out, '>', \$html) or die $!;
{
	local *STDOUT = $out;
	if ($page eq 'generate_report') {
		# This entry point is only used with a missing log, before any writes.
		die "Missing-file fixture required" unless $case->{'missing'};
		eval { main::generate_report($file, \*STDOUT, $case->{'escape'}) };
		}
	else {
		do "$root/webalizer/$page.cgi";
		}
	$error = $@;
	$error = '' if $error eq "FIXTURE_EXIT\n";
	}
close($out);
print encode_json({ html => $html, error => $error, file => $file,
	rotated => $rotated, report_dir => $report_dir, input => \%main::in,
	reports => \@reports });
