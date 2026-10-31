#!/usr/bin/perl
# Exercise CGI escaping without issuing certificates or signaling processes.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";
require "$root/ui-lib.pl";
$INC{'./acl-lib.pl'} = $INC{'./proc-lib.pl'} = 1;
*main::ReadParse = *main::switch_acl_uid = *main::webmin_log = sub { };
*main::error_setup = *main::get_miniserv_config = sub { };
*main::error = sub { die $_[0]."\n" };
*main::get_module_variable = sub { return \%main::text };
*main::ui_print_unbuffered_header = sub { };
*main::load_theme_library = sub { };
*main::get_module_name = sub { 'proc' };
*main::get_module_info = sub { return () };
*main::get_webprefix = sub { '' };
for my $file ('lang/en', 'acl/lang/en', 'proc/lang/en') {
	open(my $fh, '<', "$root/$file") or die $!;
	while (<$fh>) {
		$main::text{$1} = $2 if /^(\S+)=(.*)$/;
		}
	}

# render_cgi(file, inputs) captures the real CGI and UI helpers.
sub render_cgi
{
my ($file, $inputs) = @_;
local %main::in = %$inputs;
my $html = '';
open(my $out, '>', \$html) or die $!;
local *STDOUT = $out;
do "$root/$file";
return ($html, $@);
}

subtest 'certificate success and error output' => sub {
	# Stub only certificate I/O and account writes; preserve submitted values.
	my ($saved, $openssl_error);
	local *main::transname = local *main::tempname = sub { '/fixture/cert' };
	local *main::open_tempfile = local *main::print_tempfile =
		local *main::close_tempfile = local *main::unlink_file = sub { };
	local *main::get_ssleay = sub { 'openssl' };
	local *main::backquote_logged = sub {
		$? = $openssl_error ? 256 : 0;
		return $openssl_error || '';
		};
	local *main::list_users = sub { return {name => 'fixture'} };
	# Stop after the tested account write, before the CGI's delay and restart.
	local *main::modify_user = sub { $saved = $_[1]->{cert}; die "fixture done\n" };
	local $main::base_remote_user = 'fixture';
	my $payload = '<script>alert(1)</script>';
	for my $name ('Review User', q{O'Reilly & Partners}, $payload) {
		my ($html, $error) = render_cgi('acl/cert_issue.cgi',
			{ key => 'fixture-key', commonName => $name });
		is($error, "fixture done\n", 'successful issuance reaches account update');
		like($html, qr/\Q@{[main::html_escape($name)]}\E/,
			'common name appears as text');
		unlike($html, qr/\Q$payload\E/, 'common name cannot introduce a script');
		like($saved, qr/\Q\/CN=$name\/Email=\E/, 'stored DN retains the original name');
		}
	$openssl_error = "Invalid subject $payload\n";
	my ($html, $error) = render_cgi('acl/cert_issue.cgi',
		{ key => 'fixture-key', commonName => 'Review User' });
	like($error, qr/<pre>Invalid subject &lt;script&gt;/,
		'OpenSSL diagnostics retain preformatted markup and escape input');
	unlike($error, qr/\Q$payload\E/, 'OpenSSL errors cannot introduce a script');
	};

subtest 'single-process permission error heading' => sub {
	my ($heading, $pid);
	local *main::error_setup = sub { $heading = $_[0] };
	local *main::process_info = sub { $pid = $_[0]; return (user => 'fixture') };
	local *main::can_edit_process = sub { 0 };
	local *main::kill_logged = sub { die "unexpected signal\n" };
	my $payload = '<script>alert(1)</script>';
	for my $inputs ({signal => 'TERM', pid => '12345'},
			{signal => $payload, pid => $payload}) {
		my ($html, $error) = render_cgi('proc/kill_proc.cgi', $inputs);
		is($error, "$main::text{'kill_ecannot'}\n", 'signaling is denied');
		is($heading, main::text('kill_err',
			main::html_escape($inputs->{signal}),
			main::html_escape($inputs->{pid})),
			'error heading renders submitted values as text');
		is($pid, $inputs->{pid}, 'process lookup receives the original PID');
		}
	};

subtest 'process output and return link' => sub {
	my @signals;
	local *main::list_processes = sub { return map { +{user => 'fixture'} } @_ };
	local *main::can_edit_process = sub { 1 };
	local *main::kill_logged = sub { push @signals, [@_]; return 1 };
	my $query = 'search=worker%20name&match=1';
	my ($html, $error) = render_cgi('proc/kill_proc_list.cgi',
		{pidlist => '12345 12346', signal => 'TERM', args => $query});
	is($error, '', 'ordinary request renders successfully');
	is_deeply(\@signals, [['TERM', '12345'], ['TERM', '12346']],
		'signal and PID arguments are unchanged');
	$html =~ /href="(index_search\.cgi\?[^"]+)"/;
	is(main::html_unescape($1), "index_search.cgi?$query",
		'HTML escaping preserves the return query');

	my $payload = '<script>alert(1)</script>';
	($html, $error) = render_cgi('proc/kill_proc_list.cgi',
		{pidlist => $payload, signal => $payload, args => '">'.$payload});
	is($error, '', 'hostile values render successfully');
	unlike($html, qr/\Q$payload\E/, 'PID, signal and return link cannot inject scripts');
	like($html, qr/SIG&lt;script&gt;/, 'signal output is escaped');
	like($html, qr/href="index_search.cgi\?&quot;&gt;&lt;script&gt;/,
		'return link cannot escape its quoted attribute');
	};

done_testing();
