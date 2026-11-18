#!/usr/bin/perl
# Exercise CGI escaping without issuing certificates or signaling processes.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;
use File::Temp qw(tempdir);

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";
require "$root/ui-lib.pl";
$INC{'./acl-lib.pl'} = $INC{'./proc-lib.pl'} = 1;
# Assign each stub separately: chained glob assignments would alias the names.
for my $name ('ReadParse', 'switch_acl_uid', 'webmin_log', 'error_setup',
	      'lock_file', 'unlock_file') {
	no strict 'refs';
	*{"main::$name"} = sub { };
	}
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

# fixture_file(path) returns a fixture file's contents, or undef if missing.
sub fixture_file
{
my ($path) = @_;
open(my $fh, '<', $path) || return undef;
local $/;
return scalar(<$fh>);
}

# openssl_conf_value(value) decodes an SPKAC value the way OpenSSL's config
# parser does for the characters cert_issue.cgi escapes.
sub openssl_conf_value
{
my ($value) = @_;
$value =~ s/\\(.)/$1/g;
return $value;
}

# Shared certificate fixture: temporary files, a stub CA run that signs into
# the requested output file, and a captured account update.
my $dir = tempdir(CLEANUP => 1);
my ($tempcount, $openssl_error, $saved, $spkac, @ssleay);
my %miniserv_fixture;
*main::transname = sub { return "$dir/tmp".(++$tempcount) };
*main::pending_certificate_file = sub { return "$dir/pending.der" };
*main::open_tempfile = sub { $spkac = '' };
*main::print_tempfile = sub { $spkac .= $_[1] };
*main::close_tempfile = sub { };
*main::unlink_file = sub { unlink(@_) };
*main::copy_source_dest = sub {
	my ($src, $dst) = @_;
	my $data = &fixture_file($src);
	defined($data) || return 0;
	open(my $fh, '>', $dst) || return 0;
	print $fh $data;
	close($fh);
	return 1;
	};
*main::get_ssleay = sub { 'openssl' };
*main::backquote_logged = sub {
	my ($cmd) = @_;
	push(@ssleay, $cmd);
	if ($openssl_error) {
		$? = 256;
		return $openssl_error;
		}
	my ($out) = $cmd =~ /-out\s+(\S+)/;
	open(my $fh, '>', $out) or die $!;
	print $fh "SIGNED-CERT";
	close($fh);
	$? = 0;
	return '';
	};
*main::list_users = sub {
	return ({ name => 'other' }, { name => $main::base_remote_user });
	};
# Stop after the tested account write, before the CGI's delay and restart.
*main::modify_user = sub { $saved = [ $_[0], $_[1]->{'cert'} ];
			   die "fixture done\n" };
*main::get_miniserv_config = sub { %{$_[0]} = %miniserv_fixture };

# issue_cert(login, inputs) runs cert_issue.cgi as an allowed HTTPS user.
sub issue_cert
{
my ($login, $inputs) = @_;
local $main::base_remote_user = $login;
local %main::access = ( cert => 1 );
local $ENV{'HTTPS'} = 'ON';
%miniserv_fixture = ( ca => "$dir/ca.pem" );
($saved, $spkac, $openssl_error, @ssleay) = ( );
unlink("$dir/pending.der");
return &render_cgi('acl/cert_issue.cgi',
		   { key => 'fixture-key', %{$inputs || { }} });
}

subtest 'certificate common name is forced and escaped' => sub {
	my $payload = '<script>alert(1)</script>';
	for my $login ('fixture', q{o'reilly&co}, $payload) {
		my ($html, $error) = &issue_cert($login,
			{ commonName => 'root', organizationName => 'Example' });
		is($error, "fixture done\n",
		   'successful issuance reaches account update');
		is($saved->[0], $login, 'only the requesting account is updated');
		like($saved->[1], qr/\Q\/CN=$login\/Email=\E/,
		     'stored DN uses the login as common name');
		unlike($saved->[1], qr/CN=root/,
		       'submitted common name is ignored');
		like($spkac, qr/^commonName = (.*)$/m, 'SPKAC has a common name');
		$spkac =~ /^commonName = (.*)$/m;
		is(&openssl_conf_value($1), $login,
		   'OpenSSL signs the login as common name');
		like($html, qr/\Q@{[&main::html_escape($login)]}\E/,
		     'common name appears as text');
		unlike($html, qr/\Q$payload\E/,
		       'common name cannot introduce a script');
		like($html, qr/href='cert_output\.cgi'/,
		     'pickup link does not name a file');
		is(&fixture_file("$dir/pending.der"), 'SIGNED-CERT',
		   'signed certificate is published for pickup');
		ok(!-e "$dir/tmp2", 'signed temporary file is removed');
		}
	};

subtest 'certificate DN fields keep special characters' => sub {
	my %inputs = (
		organizationName => 'R&D/Ops',
		organizationalUnitName => q{Sales\EMEA "#1" $HOME 'x'},
		emailAddress => ' ops/admin@example.com ',
		stateOrProvinceName => 'CA',
		countryName => 'US',
		);
	my ($html, $error) = &issue_cert('fixture', \%inputs);
	is($error, "fixture done\n", 'special characters are accepted');
	my %signed = map { /^(\S+) = (.*)$/ ? ( $1, $2 ) : ( ) }
		     split(/\n/, $spkac);
	is($signed{'organizationName'}, 'R&D/Ops',
	   'slashes are passed to OpenSSL unchanged');
	is($signed{'organizationalUnitName'},
	   q{Sales\\\\EMEA \"\#1\" \$HOME \'x\'},
	   'OpenSSL config characters are escaped');
	is(&openssl_conf_value($signed{'organizationalUnitName'}),
	   $inputs{'organizationalUnitName'},
	   'OpenSSL decodes the submitted department');
	is($saved->[1], "/C=US/ST=CA/O=R&D/Ops/OU=".
			$inputs{'organizationalUnitName'}.
			"/CN=fixture/Email=ops/admin\@example.com",
	   'stored DN matches the signed values');

	for my $bad ("a:b", "a\nOU=x", "a\rb", "a\0b") {
		($html, $error) = &issue_cert('fixture',
			{ organizationName => $bad });
		is($error, "$main::text{'cert_echars'}\n",
		   'field separators and line breaks are rejected');
		ok(!@ssleay, 'OpenSSL is not run for rejected fields');
		}
	};

subtest 'certificate issuance refusals' => sub {
	my ($html, $error);
	{
		local $main::base_remote_user = 'fixture';
		local %main::access = ( cert => 0 );
		local $ENV{'HTTPS'} = 'ON';
		%miniserv_fixture = ( ca => "$dir/ca.pem" );
		@ssleay = ( );
		($html, $error) = &render_cgi('acl/cert_issue.cgi',
					      { key => 'fixture-key' });
		is($error, "$main::text{'cert_ecannot'}\n",
		   'users without certificate access are refused');
		($html, $error) = &render_cgi('acl/cert_output.cgi', { });
		is($error, "$main::text{'cert_ecannot'}\n",
		   'pickup is refused without certificate access');
		($html, $error) = &render_cgi('acl/cert_form.cgi', { });
		is($error, "$main::text{'cert_ecannot'}\n",
		   'request form is refused without certificate access');
		ok(!@ssleay, 'OpenSSL is not run without access');
	}
	{
		local $main::base_remote_user = 'fixture';
		local %main::access = ( cert => 1 );
		local $ENV{'HTTPS'};
		%miniserv_fixture = ( ca => "$dir/ca.pem" );
		@ssleay = ( );
		($html, $error) = &render_cgi('acl/cert_issue.cgi',
					      { key => 'fixture-key' });
		is($error, "$main::text{'cert_ecannot'}\n",
		   'plain HTTP requests are refused');
		$ENV{'HTTPS'} = 'ON';
		%miniserv_fixture = ( );
		($html, $error) = &render_cgi('acl/cert_issue.cgi',
					      { key => 'fixture-key' });
		is($error, "$main::text{'cert_ecannot'}\n",
		   'requests are refused without a Webmin CA');
		ok(!@ssleay, 'OpenSSL is not run when refused');
	}
	my $payload = '<script>alert(1)</script>';
	$openssl_error = "Invalid subject $payload\n";
	{
		local $main::base_remote_user = 'fixture';
		local %main::access = ( cert => 1 );
		local $ENV{'HTTPS'} = 'ON';
		%miniserv_fixture = ( ca => "$dir/ca.pem" );
		($html, $error) = &render_cgi('acl/cert_issue.cgi',
					      { key => 'fixture-key' });
	}
	$openssl_error = undef;
	like($error, qr/<pre>Invalid subject &lt;script&gt;/,
		'OpenSSL diagnostics retain preformatted markup and escape input');
	unlike($error, qr/\Q$payload\E/, 'OpenSSL errors cannot introduce a script');
	ok(!-e "$dir/pending.der", 'failed requests publish no certificate');
	};

subtest 'certificate pickup' => sub {
	local $main::base_remote_user = 'fixture';
	local %main::access = ( cert => 1 );
	open(my $fh, '>', "$dir/pending.der") or die $!;
	print $fh "SIGNED-CERT";
	close($fh);
	my ($html, $error) = &render_cgi('acl/cert_output.cgi',
					 { file => "$dir/ca.pem" });
	is($error, '', 'pending certificate is returned');
	is($html, "Content-type: application/x-x509-user-cert\n\nSIGNED-CERT",
	   'only the pending certificate is sent');
	ok(!-e "$dir/pending.der", 'certificate can be picked up only once');
	($html, $error) = &render_cgi('acl/cert_output.cgi', { });
	is($error, "$main::text{'cert_etempdir'}\n",
	   'pickup without a pending certificate fails');
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
	my (@signals, $logged);
	# Return processes out of order and owned by different users, so each
	# PID must be matched to its own process before checking access.
	local *main::list_processes = sub {
		return ({ pid => '12347', user => 'other', args => 'other' },
			{ pid => '12346', user => 'fixture', args => 'b' },
			{ pid => '12345', user => 'fixture', args => 'a' });
		};
	local *main::can_edit_process = sub { $_[0] eq 'fixture' };
	local *main::kill_logged = sub { push @signals, [@_]; return 1 };
	local *main::webmin_log = sub { $logged = { %{$_[3]} } };
	my $query = 'search=worker%20name&match=1';
	my ($html, $error) = render_cgi('proc/kill_proc_list.cgi',
		{pidlist => '12347 12345 12348 12346', signal => 'TERM',
		 args => $query});
	is($error, '', 'ordinary request renders successfully');
	is_deeply(\@signals, [['TERM', '12345'], ['TERM', '12346']],
		'only allowed PIDs are signaled, with unchanged arguments');
	is_deeply([ @$logged{'args0', 'args1', 'args2', 'args3'} ],
		  [ 'other', 'a', undef, 'b' ],
		  'each PID is logged with its own command');
	my $denied = () = $html =~ /\Q$main::text{'kill_ecannot'}\E/g;
	is($denied, 2, 'other users and missing PIDs are refused');
	$html =~ /href="(index_search\.cgi\?[^"]+)"/;
	is(main::html_unescape($1), "index_search.cgi?$query",
		'HTML escaping preserves the return query');

	my $payload = '<script>alert(1)</script>';
	@signals = ( );
	($html, $error) = render_cgi('proc/kill_proc_list.cgi',
		{pidlist => '12345', signal => $payload,
		 args => '">'.$payload});
	is($error, '', 'hostile values render successfully');
	unlike($html, qr/\Q$payload\E/,
	       'signal and return link cannot inject scripts');
	like($html, qr/SIG&lt;script&gt;/, 'signal output is escaped');
	like($html, qr/href="index_search.cgi\?&quot;&gt;&lt;script&gt;/,
		'return link cannot escape its quoted attribute');

	for my $pidlist ($payload, '12345 0', '12345 -1', '', '12345 1x') {
		@signals = ( );
		($html, $error) = render_cgi('proc/kill_proc_list.cgi',
			{pidlist => $pidlist, signal => 'TERM'});
		is($error, "$main::text{'kill_ecannot'}\n",
		   'invalid PID lists are refused');
		ok(!@signals, 'no signal is sent for an invalid PID list');
		}
	};

done_testing();
