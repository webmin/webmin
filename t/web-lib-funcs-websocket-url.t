#!/usr/bin/perl
# Tests for browser-visible WebSocket URL generation in web-lib-funcs.pl.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'web-lib-funcs.pl'));
require $script;

my %test_miniserv;
my $test_webprefix;
{
	no warnings qw(redefine once);
	*main::get_miniserv_config = sub { %{$_[0]} = %test_miniserv; };
	*main::get_webprefix = sub { return $test_webprefix; };
}

sub websocket_url {
	my (%args) = @_;
	%test_miniserv = %{$args{'config'} || { }};
	$test_webprefix = $args{'webprefix'} || '';
	my %saved_env = %ENV;
	local %ENV = %saved_env;
	delete @ENV{qw(HTTPS HTTP_HOST HTTP_X_FORWARDED_HOST
			HTTP_X_FORWARDED_PROTO HTTP_FORWARDED
			HTTP_WEBMIN_PATH)};
	$ENV{'HTTPS'} = defined($args{'https'}) ? $args{'https'} : 'off';
	$ENV{'HTTP_HOST'} = $args{'http_host'} || 'internal.example:10000';
	if ($args{'env'}) {
		foreach my $key (keys(%{$args{'env'}})) {
			$ENV{$key} = $args{'env'}->{$key};
			}
		}
	return main::get_miniserv_websocket_url(
		$args{'port'} || 555,
		$args{'host'},
		$args{'module'} || 'xterm',
		$args{'path'},
		$args{'token'});
}

is(websocket_url(),
	'ws://internal.example:10000/xterm/ws-555',
	'direct HTTP URL is unchanged');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_host => 'public.example' }),
	'wss://public.example/xterm/ws-555',
	'redirect scheme and host are used');

is(websocket_url(
	config => { redirect_ssl => 1,
		    redirect_host => 'rocky9-pro.webmin.dev' },
	host => 'host.rocky9-pro.virtualmin.dev:10000',
	path => '/servers/ws-link-1-563-linktoken',
	token => 'linktoken'),
	'wss://host.rocky9-pro.virtualmin.dev:10000/servers/'.
	'ws-link-1-563-linktoken?token=linktoken',
	'linked-server proxy URL preserves the browser-facing parent authority');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_host => 'public.example',
		    redirect_port => 8443 }),
	'wss://public.example:8443/xterm/ws-555',
	'non-default redirect port is used with redirect host');

is(websocket_url(
	config => { redirect_ssl => 1,
		    redirect_host => 'public.example:9443' }),
	'wss://public.example:9443/xterm/ws-555',
	'embedded redirect host port is preserved without port override');

is(websocket_url(
	config => { redirect_port => 8443 },
	http_host => 'public.example'),
	'ws://public.example:8443/xterm/ws-555',
	'redirect port is used without redirect scheme or host');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_port => 8443 },
	http_host => 'public.example:10000'),
	'wss://public.example:8443/xterm/ws-555',
	'redirect port replaces request host port');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_port => 8443,
		    trust_real_ip => 1 },
	env => { HTTP_X_FORWARDED_HOST => 'proxy.example:9443' }),
	'wss://proxy.example:8443/xterm/ws-555',
	'redirect port replaces trusted proxy host port');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_port => 443 },
	http_host => 'public.example:10000'),
	'wss://public.example/xterm/ws-555',
	'default secure redirect port is omitted');

is(websocket_url(
	config => { redirect_ssl => 0, redirect_port => 80 },
	https => 'on', http_host => 'public.example:10000'),
	'ws://public.example/xterm/ws-555',
	'default insecure redirect port is omitted');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_port => 8443,
		    websocket_host => 'wss://socket.example:9443' }),
	'wss://socket.example:9443/xterm/ws-555',
	'explicit WebSocket host and port take precedence');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_port => 8443 },
	host => 'caller.example:9555'),
	'wss://caller.example:9555/xterm/ws-555',
	'caller-provided host and port take precedence');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_port => 8443 },
	http_host => '[2001:db8::1]:10000'),
	'wss://[2001:db8::1]:8443/xterm/ws-555',
	'redirect port replaces bracketed IPv6 request port');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_port => 8443 },
	http_host => 'cafe:8080'),
	'wss://cafe:8443/xterm/ws-555',
	'hexadecimal-looking hostname is not mistaken for IPv6');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_port => 8443 },
	http_host => 'beef'),
	'wss://beef:8443/xterm/ws-555',
	'single-label hexadecimal hostname is not bracketed');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_host => '2001:db8::2',
		    redirect_port => 443 }),
	'wss://[2001:db8::2]/xterm/ws-555',
	'IPv6 redirect host is bracketed and default port omitted');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_host => 'public.example',
		    redirect_prefix => '/webmin' },
	webprefix => '/webmin'),
	'wss://public.example/webmin/xterm/ws-555',
	'documented subdirectory proxy prefix is appended once');

is(websocket_url(
	config => { redirect_ssl => 1, trust_real_ip => 1 },
	env => { HTTP_X_FORWARDED_PROTO => 'http',
		 HTTP_X_FORWARDED_HOST => 'proxy.example' }),
	'wss://proxy.example/xterm/ws-555',
	'redirect scheme takes precedence over trusted proxy scheme');

is(websocket_url(
	config => { trust_real_ip => 1 },
	env => { HTTP_X_FORWARDED_PROTO => 'https',
		 HTTP_X_FORWARDED_HOST => 'proxy.example:9443' }),
	'wss://proxy.example:9443/xterm/ws-555',
	'trusted proxy host and port pass through without redirect overrides');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_port => 8443,
		    trust_real_ip => 1 },
	env => { HTTP_X_FORWARDED_HOST => 'public.example, edge.internal:10000' }),
	'wss://public.example:8443/xterm/ws-555',
	'comma-separated forwarded host uses the first entry');

is(websocket_url(
	config => { redirect_port => 'bogus' },
	http_host => 'public.example:10000'),
	'ws://public.example:10000/xterm/ws-555',
	'non-numeric redirect port is ignored');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_host => 'public.example',
		    redirect_port => 8443 },
	http_host => 'child.example',
	env => { HTTP_WEBMIN_PATH =>
		 'https://parent.example/servers/link.cgi/1/xterm/index.cgi' }),
	'ws://child.example/xterm/ws-555',
	'linked-server response retains the child connection authority');

is(websocket_url(
	config => { redirect_ssl => 1, redirect_host => 'public.example',
		    redirect_port => 8443,
		    websocket_host => 'wss://socket.example:9443' },
	host => 'caller.example:9555',
	http_host => 'child.example',
	env => { HTTP_WEBMIN_PATH =>
		 'https://parent.example/servers/link.cgi/1/xterm/index.cgi' }),
	'ws://child.example/xterm/ws-555',
	'linked-server response ignores explicit public WebSocket hosts');

done_testing();
