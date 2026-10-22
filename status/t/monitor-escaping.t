#!/usr/bin/perl
# Check service responses with real protocol parsers and in-memory I/O.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;

my $root = "$FindBin::Bin/../..";
require "$root/web-lib-funcs.pl";
require "$root/ui-lib.pl";
$main::root_directory = $root;
for my $file (qw(status/lang/en mailboxes/lang/en)) {
	open(my $fh, '<', "$root/$file") or die "open $file: $!";
	while (<$fh>) {
		$main::text{$1} = $2 if /^(\S+)=(.*)$/;
		}
	close($fh);
	}
{
	package mailboxes;
	require "$root/mailboxes/boxes-lib.pl";
	require "$root/mailboxes/folders-lib.pl";
}
for my $type (qw(ftp smtp imap ldap query)) {
	do "$root/status/$type-monitor.pl";
	die $@ if $@;
	}

# FixtureSocket provides canned replies without opening workstation sockets.
{
	package FixtureSocket;
	sub TIEHANDLE { bless { replies => $_[1] }, $_[0] }
	sub READLINE { shift @{$_[0]->{replies}} }
	sub PRINT { 1 }
	sub CLOSE { 1 }
	sub FILENO { -1 }
}
my (@replies, @handles);
*main::open_socket = sub {
	my $handle = $_[2];
	$handle = caller()."::$handle" unless $handle =~ /::/;
	no strict 'refs';
	tie *{$handle}, 'FixtureSocket', \@replies;
	push(@handles, $handle);
	return '192.0.2.1';
	};
*main::foreign_require = sub { };
*main::get_system_hostname = sub { 'fixture.invalid' };
*main::is_readonly_mode = sub { 0 };
*main::check_in_http_cache = sub { return; };
*main::write_to_http_cache = sub { };
*main::transname = sub { 'unused-monitor-fixture' };
*main::callers_package = sub { $_[0] =~ /::/ ? $_[0] : 'main::'.$_[0] };
*main::read_http_connection = sub { shift @replies };
*main::write_http_connection = sub { };
*main::close_http_connection = sub { };
*main::error = sub { die join('', @_)."\n" };
for my $name (qw(open_socket read_http_connection write_http_connection
		close_http_connection text error html_escape)) {
	no strict 'refs';
	*{"mailboxes::$name"} = \&{"main::$name"};
	}
open(local *mailboxes::DEBUG, '>', \my $debug) or die $!;

# run_monitor(type, replies, [options]) runs one check with isolated state.
sub run_monitor
{
my ($type, $lines, $options) = @_;
local %main::gconfig;
local $main::error_must_die;
local %mailboxes::imap_login_handle;
local %mailboxes::imap_login_ssl;
local $mailboxes::imap_command_count = 0;
@replies = @$lines;
my $func = "main::get_${type}_status";
my $result;
{
	no strict 'refs';
	$result = &$func({ host => 'fixture.invalid', port => 1234,
		user => 'fixture', pass => 'not-a-real-password', %{$options || {}} });
	untie *{$_} for @handles;
	}
@handles = ();
alarm(0);
return $result;
}

# check_error(status, payload, label) also checks the actual HTML table helper.
sub check_error
{
my ($result, $payload, $label) = @_;
is($result->{'up'}, 0, "$label reports failure");
like($result->{'desc'}, qr/\Q@{[main::html_escape($payload)]}\E/,
	"$label keeps the escaped diagnostic");
local $main::ui_table_cols = 2;
local $main::ui_table_pos = 0;
my $html = main::ui_table_row('Status', $result->{'desc'});
unlike($html, qr/<(?:img|svg|script)\b/i, "$label cannot insert active HTML");
}

my $payload = '<img src=x onerror="alert(1)"> & diagnostic';
subtest 'FTP greeting, login, and download errors' => sub {
	for my $case (
		[ 'greeting', [ "500 $payload\r\n" ], {} ],
		[ 'login', [ "220 ready\r\n", "530 $payload\r\n" ], {} ],
		[ 'download', [ "220 ready\r\n", "230 logged in\r\n",
			"200 binary\r\n", "550 $payload\r\n" ], { file => '/test' } ],
		) {
		check_error(run_monitor('ftp', $case->[1], $case->[2]),
			$payload, "FTP $case->[0]");
		}
	my $ok = run_monitor('ftp', [ "220 ready\r\n", "230 logged in\r\n", "221 bye\r\n" ]);
	is($ok->{'up'}, 1, 'FTP success is unchanged');
	ok(!defined($ok->{'desc'}), 'FTP success has no error description');
	};

subtest 'SMTP escaped protocol errors and raw exceptions' => sub {
	for my $case (
		[ 'greeting', [ "500 $payload\r\n" ], {} ],
		[ 'HELO', [ "220 ready\r\n", "500 $payload\r\n" ], {} ],
		[ 'sender', [ "220 ready\r\n", "250 hello\r\n", "550 $payload\r\n" ],
			{ from => 'sender@example.invalid' } ],
		[ 'recipient', [ "220 ready\r\n", "250 hello\r\n", "550 $payload\r\n" ],
			{ to => 'recipient@example.invalid' } ],
		) {
		check_error(run_monitor('smtp', $case->[1], { user => '', %{$case->[2]} }),
			$payload, "SMTP $case->[0]");
		}
	{
		local *mailboxes::smtp_command = sub { die "SMTP authentication failed : $payload\n" };
		check_error(run_monitor('smtp', []), $payload, 'SMTP raw exception');
		}
	my $ok = run_monitor('smtp', [ "220 ready\r\n", "250 hello\r\n", "221 bye\r\n" ], { user => '' });
	is($ok->{'up'}, 1, 'SMTP success is unchanged');
	is($ok->{'desc'}, $main::text{'smtp_ok1'}, 'SMTP success description is unchanged');
	{
		local $INC{'Authen/SASL.pm'} = __FILE__;
		local *Authen::SASL::new = sub { bless {}, 'FixtureSASL' };
		local *FixtureSASL::client_new = sub { bless {}, 'FixtureSASL' };
		local *FixtureSASL::client_start = sub { 'fixture' };
		check_error(run_monitor('smtp', [ "220 ready\r\n", "250 hello\r\n",
			"334 continue\r\n", "535 $payload\r\n" ]), $payload, 'SMTP authentication');
		my $auth = run_monitor('smtp', [ "220 ready\r\n", "250 hello\r\n",
			"334 continue\r\n", "235 authenticated\r\n", "221 bye\r\n" ]);
		is($auth->{'up'}, 1, 'SMTP authentication success is unchanged');
		is($auth->{'desc'}, $main::text{'smtp_ok4'}, 'SMTP authenticated description is unchanged');
		}
	};

subtest 'FTPS errors from the optional client library' => sub {
	local $INC{'Net/FTPSSL.pm'} = __FILE__;
	my $stage;
	local *Net::FTPSSL::new = sub {
		die "$payload\n" if $stage eq 'connect';
		return bless {}, 'Net::FTPSSL';
		};
	local *Net::FTPSSL::login = sub { $stage ne 'login' };
	local *Net::FTPSSL::get = sub { $stage ne 'download' };
	local *Net::FTPSSL::last_message = sub { $payload };
	local *Net::FTPSSL::quit = sub { };
	for my $test_stage (qw(connect login download)) {
		$stage = $test_stage;
		check_error(run_monitor('ftp', [], { tls => 1, file => '/fixture' }),
			$payload, "FTPS $stage");
		}
	$stage = 'success';
	my $ok = run_monitor('ftp', [], { tls => 1, file => '/fixture' });
	is($ok->{'up'}, 1, 'FTPS success is unchanged');
	ok(!defined($ok->{'desc'}), 'FTPS success has no error description');
	};

subtest 'IMAP greeting, login, selection, and exception errors' => sub {
	for my $case (
		[ 'greeting', [ "* BYE $payload\r\n" ] ],
		[ 'login', [ "* OK ready\r\n", "$$-1 NO $payload\r\n" ] ],
		[ 'selection', [ "* OK ready\r\n", "$$-1 OK logged in\r\n", "$$-2 NO $payload\r\n" ] ],
		) {
		check_error(run_monitor('imap', $case->[1]), $payload, "IMAP $case->[0]");
		}
	{
		local *mailboxes::imap_login = sub { die main::html_escape($payload)."\n" };
		check_error(run_monitor('imap', []), $payload, 'IMAP encoded exception');
		}
	my $ok = run_monitor('imap', [ "* OK ready\r\n", "$$-1 OK logged in\r\n",
		"* 7 EXISTS\r\n", "$$-2 OK selected\r\n" ]);
	is_deeply($ok, { up => 1, desc => 'Login OK, found 7 messages' },
		'IMAP success and message count are unchanged');
	};

# Mock only optional LDAP/DBI dependencies; exercise the actual monitor code.
subtest 'LDAP server errors' => sub {
	local $INC{'Net/LDAP.pm'} = __FILE__;
	local *ldap_client::generic_ldap_connect = sub { "Login failed : $payload" };
	check_error(get_ldap_status({}), $payload, 'LDAP login');
	{
		local *ldap_client::generic_ldap_connect = sub { main::html_escape($payload) };
		is(get_ldap_status({})->{'desc'}, main::html_escape($payload),
			'LDAP already-escaped errors are not double escaped');
		}
	{
		local *ldap_client::generic_ldap_connect = sub { bless {}, 'Net::LDAP' };
		is(get_ldap_status({})->{'up'}, 1, 'LDAP success is unchanged');
		}
	};

subtest 'SQL connection, query errors, and returned data' => sub {
	local $INC{'DBI.pm'} = __FILE__;
	my $stage;
	local *DBI::install_driver = sub { bless {}, 'FixtureDB' };
	local *main::make_dbistr = sub { 'fixture' };
	local *FixtureDB::connect = sub { $stage eq 'connect' ? undef : bless {}, 'FixtureDB' };
	local *FixtureDB::prepare = sub { $stage eq 'prepare' ? undef : bless {}, 'FixtureDB' };
	local *FixtureDB::execute = sub { $stage ne 'execute' };
	local *FixtureDB::errstr = sub { $payload };
	local *FixtureDB::fetchrow = sub { $stage eq 'result' ? $payload : 'OK' };
	local *FixtureDB::finish = sub { };
	for my $test_stage (qw(connect prepare execute result)) {
		$stage = $test_stage;
		check_error(get_query_status({ driver => 'mysql', result => 'OK' }),
			$payload, "SQL $stage");
		}
	$stage = 'success';
	is(get_query_status({ driver => 'mysql', result => 'OK' })->{'up'}, 1,
		'SQL success is unchanged');
	};

done_testing();
