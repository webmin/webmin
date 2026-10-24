#!/usr/bin/perl
# Exercise the real SMTP parser without opening sockets on the workstation.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";
require "$root/mailboxes/boxes-lib.pl";
require "$root/status/smtp-monitor.pl";

my (@replies, @sent, $tls, $closed, $handshake_error);
*main::foreign_require = sub { };
*main::open_socket = sub { };
*main::get_system_hostname = sub { 'fixture.invalid' };
*main::is_readonly_mode = sub { 0 };
*main::close_http_connection = sub { $closed++; return 1 };
*main::error = sub { die join('', @_)."\n" };
*main::read_http_connection = sub { shift @replies };
*main::write_http_connection = sub {
	push(@sent, [ join('', @_[1..$#_]), $tls ]);
	return 1;
	};
*main::switch_smtp_to_ssl = sub {
	die "TLS handshake failed\n" if $handshake_error;
	$tls = 1;
	};
*mailboxes::smtp_command = \&main::smtp_command;

# Only SASL setup is mocked; authentication may not start before TLS succeeds.
$INC{'Authen/SASL.pm'} = __FILE__;
*Authen::SASL::new = sub { bless {}, 'FixtureSASL' };
*FixtureSASL::client_new = sub { $_[0] };
*FixtureSASL::client_start = sub { "\0fixture-user\0fixture-password" };
$main::text{'smtp_ok4'} = 'Authenticated';

# run_smtp(mode, replies, [ssl], [user], [handshake-failure], [config-credentials])
# Run the monitor or sender and return success, error and the monitor settings.
sub run_smtp
{
my ($mode, $responses, $ssl, $user, $fail, $configured) = @_;
$ssl = 2 if !defined($ssl);
$user = 'fixture-user' if !defined($user);
@replies = @$responses;
@sent = ();
($tls, $closed, $handshake_error) = (0, 0, $fail);
local %main::config = $configured ? (
	smtp_user => $user, smtp_pass => 'fixture-password',
	smtp_auth => 'Plain', smtp_ssl => $ssl) : ();
local %main::userconfig;
my $service = { host => 'fixture.invalid', port => 25, ssl => $ssl,
	user => $user, pass => 'fixture-password' };
my ($ok, $error);
if ($mode eq 'monitor') {
	my $result = main::get_smtp_status($service);
	($ok, $error) = ($result->{'up'}, $result->{'desc'});
	}
else {
	my $mail = { headers => [ [ 'From', 'from@example.invalid' ],
		[ 'To', 'to@example.invalid' ] ], body => "Fixture mail\n", attach => [] };
	$ok = eval {
		main::send_mail($mail, undef, undef, undef, 'fixture.invalid',
			$configured ? undef : $user,
			$configured ? undef : 'fixture-password', 'Plain', undef, 25,
			$configured ? undef : $ssl) > 0;
		};
	$error = $@;
	}
return ($ok, $error, $service);
}

for my $mode (qw(monitor sender)) {
	subtest "$mode rejects failed STARTTLS" => sub {
		for my $reply ("454 TLS unavailable\r\n", "500 Not supported\r\n",
			"250 Not a TLS upgrade\r\n", "2200 Invalid status\r\n", undef,
			"454 <img src=x onerror=alert(1)>\r\n") {
			for my $user ('fixture-user', '') {
				my ($ok, $error, $service) = run_smtp($mode,
					[ "220 ready\r\n", "250 hello\r\n", $reply ], 2, $user);
				ok(!$ok, 'failed upgrade is not accepted');
				like($error, qr/SMTP STARTTLS failed/, 'error identifies STARTTLS');
				unlike($error, qr/<img/, 'server response cannot inject HTML');
				is_deeply([ map { $_->[0] } @sent ],
					[ "ehlo fixture.invalid\r\n", "starttls\r\n" ],
					'no credentials, envelope or message sent after rejection');
				is($tls, 0, 'no TLS handshake attempted');
				is($closed, 1, 'rejected connection closed');
				is($service->{'ssl'}, 2, 'configured TLS mode not changed');
				}
			}
		};

	subtest "$mode succeeds in supported connection modes" => sub {
		for my $ssl (2, 1, 0) {
			my @responses = ("220 ready\r\n", "250 hello\r\n");
			push(@responses, "220 Ready for TLS\r\n", "250 secure hello\r\n") if $ssl == 2;
			push(@responses, "334 continue\r\n", "235 authenticated\r\n");
			push(@responses, "250 sender\r\n", "250 recipient\r\n", "354 data\r\n", "250 queued\r\n")
				if $mode eq 'sender';
			push(@responses, "221 bye\r\n");
			my ($ok, $error) = run_smtp($mode, \@responses, $ssl);
			ok($ok, "mode $ssl succeeds") or diag($error);
			my @auth = grep { $_->[0] =~ /^auth /i } @sent;
			is(scalar(@auth), 1, 'authentication attempted once');
			is($auth[0]->[1], $ssl ? 1 : 0, 'authentication uses the requested transport');
			my @ehlo = grep { $_->[0] =~ /^ehlo / } @sent;
			is(scalar(@ehlo), $ssl == 2 ? 2 : 1, 'EHLO repeated only after STARTTLS');
			is(scalar(@replies), 0, 'protocol completes');
			is($closed, 1, 'successful connection closed');
			}
		};

	subtest "$mode stops on handshake failure" => sub {
		my ($ok, $error) = run_smtp($mode,
			[ "220 ready\r\n", "250 hello\r\n", "220 Ready for TLS\r\n" ],
			2, undef, 1);
		ok(!$ok, 'failed handshake stops the operation');
		like($error, qr/TLS handshake failed/, 'handshake failure reported');
		is_deeply([ map { $_->[0] } @sent ],
			[ "ehlo fixture.invalid\r\n", "starttls\r\n" ],
			'authentication and mail cannot follow a failed handshake');
		};
	}

subtest 'sender configuration credentials also fail closed' => sub {
	my ($ok, $error) = run_smtp('sender',
		[ "220 ready\r\n", "250 hello\r\n", "454 unavailable\r\n" ],
		2, undef, 0, 1);
	ok(!$ok, 'configured STARTTLS failure stops sending');
	like($error, qr/SMTP STARTTLS failed/, 'configured sender reports failure');
	is_deeply([ map { $_->[0] } @sent ],
		[ "ehlo fixture.invalid\r\n", "starttls\r\n" ],
		'configuration credentials never sent');
	};
done_testing();
