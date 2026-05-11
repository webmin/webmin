#!/usr/bin/perl
# Tests for miniserv::http_error.
#
# miniserv.pl is loaded as a module; its top-level script body is skipped
# by the `unless (caller) { ... }` guard, so we only get the sub
# definitions plus a handful of pure-constant globals (@itoa64, @weekday,
# @month, @miniserv_argv). Everything else (%config, @roots, $datestr,
# etc.) we populate ourselves.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'miniserv.pl'));
require $script;

# Capture buffers populated by the overridden I/O subs.
our @written;
our @errlog;
our @reqlog;

# Replace the subs that would otherwise touch SOCK, STDERR, the log file,
# or read disk. Each capturing override is the minimum needed to keep
# http_error's control flow intact. `once` is suppressed because these
# package globals are only ever written from this file.
{
	no warnings qw(redefine once);
	*miniserv::write_data         = sub { push @written, join('', @_); };
	*miniserv::write_keep_alive   = sub { };
	*miniserv::log_error          = sub { push @errlog, join('', @_); };
	*miniserv::log_request        = sub { push @reqlog, [@_]; };
	*miniserv::embed_error_styles = sub { return ''; };
	*miniserv::server_info        = sub { return 'MiniServ/test'; };
	*miniserv::reset_byte_count   = sub { };
	*miniserv::byte_count         = sub { return 0; };
}

{
	no warnings 'once';
	%miniserv::config   = ();
	@miniserv::roots    = ('/tmp');
	@miniserv::preroots = ();
	$miniserv::datestr  = 'Sun, 01 Jan 2026 00:00:00 GMT';
}

# Call http_error with capture buffers reset. noexit=1 is REQUIRED — the
# real sub calls exit() otherwise. shutdown(SOCK,1)/close(SOCK) at the end
# of http_error warn because SOCK is not a real socket here; the localized
# warn handler swallows that one specific noise.
sub run_http_error {
	my (%args) = @_;
	@written = ();
	@errlog  = ();
	@reqlog  = ();
	no warnings 'once';
	local $miniserv::reqline  = $args{reqline};
	local $miniserv::loghost  = $args{loghost};
	local $miniserv::authuser = $args{authuser};
	local $SIG{__WARN__} = sub { };
	miniserv::http_error(
		$args{code}, $args{msg}, $args{body},
		1,             # noexit
		$args{noerr},
	);
	return join('', @written);
}

# --- minimal call: code + message, no body, no reqline ------------------
# Assert on the contract, not the cosmetics: the status code, the
# presence of required headers, and that the caller's code + message
# reach the rendered page. Specific wording, header values, decoration
# (&mdash;), and class names are presentation and may change.
{
	my $out = run_http_error(code => 404, msg => 'Not Found');

	like($out, qr{^HTTP/1\.0 404\b},                      'status line carries 404');
	like($out, qr{\r\nServer:\s+\S},                      'Server header present and non-empty');
	like($out, qr{\r\nDate:\s+\S},                        'Date header present and non-empty');
	like($out, qr{\r\nContent-type:\s*text/html\b.*\butf-?8\b}i, 'Content-type is HTML with utf-8 charset');
	like($out, qr{<title>[^<]*404[^<]*</title>},          'title surfaces the code');
	like($out, qr{<title>[^<]*Not Found[^<]*</title>},    'title surfaces the message');
	like($out, qr{<h2\b[^>]*>[^<]*Not Found[^<]*</h2>},   'message appears in a heading');
	unlike($out, qr{<p\b},                                'no paragraph emitted when body arg absent');

	is(scalar @errlog, 1,                                 'log_error called once');
	like($errlog[0], qr/Not Found/,                       'log_error received the caller message');
	is(scalar @reqlog, 0,                                 'log_request skipped when reqline empty');
}

# --- body argument renders as a paragraph -------------------------------
{
	my $out = run_http_error(code => 500, msg => 'Server Error', body => 'something broke');
	like($out, qr{<p\b[^>]*>[^<]*\Qsomething broke\E[^<]*</p>}, 'body argument rendered in a paragraph');
}

# --- reqline triggers log_request ---------------------------------------
{
	run_http_error(
		code => 403, msg => 'Forbidden', body => 'no access',
		reqline => 'GET /secret HTTP/1.0',
		loghost => '127.0.0.1', authuser => 'bob',
	);
	is(scalar @reqlog, 1,                                 'log_request called when reqline is set');
	is($reqlog[0][0], '127.0.0.1',                        'log_request host arg');
	is($reqlog[0][1], 'bob',                              'log_request user arg');
	is($reqlog[0][2], 'GET /secret HTTP/1.0',             'log_request request arg');
	is($reqlog[0][3], 403,                                'log_request code arg');
}

# --- noerr suppresses log_error -----------------------------------------
{
	run_http_error(code => 401, msg => 'Unauthorized', noerr => 1);
	is(scalar @errlog, 0,                                 'log_error suppressed when noerr is true');
}

# --- error_handler config that points to a missing file falls through ---
# This exercises the early branch without triggering `goto rerun` (which
# only resolves inside handle_request).
{
	local $miniserv::config{'error_handler'} = 'definitely-not-a-real-file.cgi';
	my $out = run_http_error(code => 500, msg => 'Server Error');
	like($out, qr{^HTTP/1\.0 500\b}, 'falls through to standard path when handler file missing');
}

# --- HTML scaffolding is balanced ---------------------------------------
{
	my $out = run_http_error(code => 400, msg => 'Bad Request', body => 'oops');
	for my $tag (qw(html head title body h2 p)) {
		my $open  = () = $out =~ /<$tag\b[^>]*>/g;
		my $close = () = $out =~ /<\/$tag>/g;
		is($open, $close, "<$tag> tags balanced (open=$open, close=$close)");
		cmp_ok($open, '>=', 1, "<$tag> appears at least once");
	}
	# Sanity-check element ordering: head before body, title inside head.
	like($out, qr{<html>.*<head>.*<title>.*</title>.*</head>.*<body[^>]*>.*</body>\s*</html>}s,
	     'top-level elements appear in the expected order');
}

done_testing();
