#!/usr/local/bin/perl
# link.cgi
# Forward the URL from path_info on to another webmin server

if ($ENV{'PATH_INFO'} =~ /^\/(\d+)\/([a-zA-Z0-9\-\/]+)\.(jar|class|gif|png)$/) {
	# Allow fetches of Java classes and images without a referer header,
	# as Java sometimes doesn't provide these
	$trust_unknown_referers = 1;
	}
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './servers-lib.pl';
our (%text, %gconfig, %access, $module_name, %tconfig);
$ENV{'PATH_INFO'} =~ /^\/(\d+)(.*)$/ ||
	&error("Bad PATH_INFO : $ENV{'PATH_INFO'}");
my $id = $1;
my $path = $2 ? &urlize("$2") : '/';
$path =~ s/^%2F/\//;
if ($ENV{'QUERY_STRING'}) {
	$path .= '?'.$ENV{'QUERY_STRING'};
	}
elsif (@ARGV) {
	$path .= '?'.join('+', @ARGV);
	}
my $s = &get_server($id);
&can_use_server($s) || &error($text{'link_ecannot'});
$access{'links'} || &error($text{'link_ecannot'});
my $url = "@{[&get_webprefix()]}/$module_name/link.cgi/$s->{'id'}";
$| = 1;
my $meth = $ENV{'REQUEST_METHOD'};
my %miniserv;
&get_miniserv_config(\%miniserv);

my ($user, $pass);
if ($s->{'autouser'}) {
	# Login is variable .. check if we have it yet
	if ($ENV{'HTTP_COOKIE'} =~ /$id=(\S+)/) {
		# Yes - set the login and password to use
		($user, $pass) = split(/:/, &decode_base64("$1"));
		}
	else {
		# No - need to display a login form
		&ui_print_header(undef, $text{'login_title'}, "");

		print &text('login_desc', "<tt>$s->{'host'}</tt>"),"<p>\n";

		print &ui_form_start(
			"@{[&get_webprefix()]}/$module_name/login.cgi", "post");
		print &ui_hidden("id", $id);

		print &ui_table_start($text{'login_header'}, undef, 2);
		print &ui_table_row($text{'login_user'},
			&ui_textbox("user", undef, 20));
		print &ui_table_row($text{'login_pass'},
			&ui_password("pass", undef, 20));
		print &ui_table_end();

		print &ui_form_end([ [ undef, $text{'login_login'} ] ]);

		&ui_print_footer("", $text{'index_return'});
		exit;
		}
	}
elsif ($s->{'sameuser'}) {
	# Login comes from this server
	$user = $main::remote_user;
	defined($main::remote_pass) || &error($text{'login_esame'});
	$pass = $main::remote_pass;
	}
else {
	# Login is fixed
	$user = $s->{'user'};
	$pass = $s->{'pass'};
	}

# Connect to the server
my $con = &make_http_connection($s->{'ip'} || $s->{'host'}, $s->{'port'},
			        $s->{'ssl'}, $meth, $path, undef, undef,
				{ 'host' => $s->{'host'},
				  'nocheckhost' => !$s->{'checkssl'} });
&error($con) if (!ref($con));

# Send request headers
&write_http_connection($con, "Host: $s->{'host'}\r\n");
&write_http_connection($con, "User-agent: Webmin\r\n");
my $auth = &encode_base64("$user:$pass");
$auth =~ s/\n//g;
&write_http_connection($con, "Authorization: basic $auth\r\n");
my ($http_host, $http_port);
if ($ENV{'HTTP_HOST'} =~ /^(\S+):(\d+)$/) {
	# Browser supplies port
	$http_host = $1;
	$http_port = $2;
	}
elsif ($ENV{'HTTP_HOST'}) {
	# Browser only supplies host
	$http_host = $ENV{'HTTP_HOST'};
	$http_port = $ENV{'SERVER_PORT'} || $miniserv{'port'} || 80;
	}
else {
	# Web server supplies host and port
	$http_host = $ENV{'SERVER_NAME'};
	$http_port = $ENV{'SERVER_PORT'};
	}
my $http_prot = $ENV{'HTTPS'} eq "ON" ? "https" : "http";
&write_http_connection($con, sprintf(
			"Webmin-servers: %s://%s:%d%s/%s\n",
			$http_prot, $http_host, $http_port,
			@{[&get_webprefix()]},
			$tconfig{'inframe'} ? "" : "$module_name/"));
&write_http_connection($con, sprintf(
			"Webmin-path: %s://%s:%d%s/%s/link.cgi%s\n",
			$http_prot, $http_host, $http_port,
			@{[&get_webprefix()]}, $module_name,
			$ENV{'PATH_INFO'}));
if ($ENV{'HTTP_WEBMIN_PATH'}) {
	&write_http_connection($con, sprintf(
			"Complete-webmin-path: %s%s\n",
			$ENV{'HTTP_WEBMIN_PATH'}));
	}
else {
	&write_http_connection($con, sprintf(
			"Complete-webmin-path: %s://%s:%d%s/%s/link.cgi%s\n",
			$http_prot, $http_host, $http_port,
			@{[&get_webprefix()]}, $module_name,
			$ENV{'PATH_INFO'}));
	}
my $cl = $ENV{'CONTENT_LENGTH'};
&write_http_connection($con, "Content-length: $cl\r\n") if ($cl);
&write_http_connection($con, "Content-type: $ENV{'CONTENT_TYPE'}\r\n")
	if ($ENV{'CONTENT_TYPE'});
my $ref = $ENV{'HTTP_REFERER'};
if ($ref && $ref =~ /^.*\Q$url\E(.*)/) {
	my $rurl = ($s->{'ssl'} ? 'https' : 'http').'://'.$s->{'host'}.
		   ':'.$s->{'port'}.$1;
	&write_http_connection($con, "Referer: $rurl\r\n");
	}
&write_http_connection($con, "\r\n");
my $post;
if ($cl) {
	&read_fully(\*STDIN, \$post, $cl);
	&write_http_connection($con, $post);
	}

# read back the headers
my $dummy = &read_http_connection($con);
my ($header, $headers, $bad) = &read_http_headers($con);
if ($bad) {
	# Normalized and truncated
	$bad =~ s/[\x00-\x1f\x7f]+/ /g;
	$bad =~ s/\s+/ /g;
	$bad =~ s/^\s+|\s+$//g;
	$bad = substr($bad, 0, 200).(length($bad) > 200 ? "..." : "");
	&error("Bad header : ".&html_escape($bad));
	}

my $defport = $s->{'ssl'} ? 443 : 80;
if ($header->{'location'} &&
    ($header->{'location'} =~ /^(http|https):\/\/$s->{'host'}:$s->{'port'}(.*)$/||
     $header->{'location'} =~ /^(http|https):\/\/$s->{'host'}(.*)/ &&
     $s->{'port'} == $defport)) {
	# fix a redirect
	local $gconfig{'webprefixnoredir'} = 1;		# We've already added
							# webprefix, so no need
							# to add it again
	&redirect("$url$2");
	exit;
	}
elsif ($header->{'www-authenticate'}) {
	# Invalid login
	my $detail = &get_http_auth_reason($header);
	if ($s->{'autouser'}) {
		print "Set-Cookie: $id=; path=/\n";
		my $msg = &text('link_eautologin', $s->{'host'},
		     "@{[&get_webprefix()]}/$module_name/link.cgi/$id/");
		$msg .= "<br>".&html_escape($detail) if ($detail);
		&error($msg);
		}
	else {
		my $msg = &text('link_elogin', $s->{'host'}, $user);
		$msg .= " : ".&html_escape($detail) if ($detail);
		&error($msg);
		}
	}
else {
	# just output the headers
	print $headers,"\n";
	}

# read back the rest of the page
if ($header->{'content-type'} &&
    $header->{'content-type'} =~ /text\/html/) {
	# Fix up HTML. Websocket URLs must always be proxied via a local
	# miniserv ws-link route, even when the linked server sets x-no-links
	# (as themes do for AJAX page loads), because a websocket connection
	# cannot be tunnelled through link.cgi itself.
	my $dolinks = !$header->{'x-no-links'};
	my %websocket_links;
	&cleanup_link_websockets();
	while($_ = &read_http_connection($con)) {
		# Websocket URLs can appear in JavaScript strings or JSON values,
		# where slashes are escaped. Ordinary HTML rewrites remain gated
		# below by x-no-links, but websocket URLs always need local routes.
		s#(['"])(wss?://[^'"]+)#
			"$1".&register_link_websocket(
				$2, $s, $auth, \%websocket_links)#egi;
		s#(['"])(wss?:\\/\\/[^'"]+)#
			"$1".&register_link_websocket(
				$2, $s, $auth, \%websocket_links)#egi;
		if ($dolinks) {
			s/src='(\/[^']*)'/src='$url$1'/gi;
			s/src="(\/[^"]*)"/src="$url$1"/gi;
			s/src=(\/[^ "'>]*)/src=$url$1/gi;
			s/href='(\/[^']*)'/href='$url$1'/gi;
			s/href="(\/[^"]*)"/href="$url$1"/gi;
			s/href=(\/[^ >"']*)/href=$url$1/gi;
			s/action='(\/[^']*)'/action='$url$1'/gi;
			s/action="(\/[^"]*)"/action="$url$1"/gi;
			s/action=(\/[^ "'>]*)/action=$url$1/gi;
			s/\.location\s*=\s*'(\/[^']*)'/.location='$url$1'/gi;
			s/\.location\s*=\s*"(\/[^']*)"/.location="$url$1"/gi;
			s/window.open\("(\/[^"]*)"/window.open\("$url$1"/gi;
			s/name=return\s+value="(\/[^"]*)"/name=return value="$url$1"/gi;
			s/param\s+name=config\s+value='(\/[^']*)'/param name=config value='$url$1'/gi;
			s/param\s+name=config\s+value="(\/[^']*)"/param name=config value="$url$1"/gi;
			s/param\s+name=config\s+value=(\/[^']*)/param name=config value=$url$1/gi;
			}
		print;
		if ($dolinks && /<applet.*archive=file.jar.*>/) {
			# Remote webmin file manager applet - give it the
			# session ID on *this* system
			print "<param name=session value=\"$main::session_id\">\n";
			}
		}
	}
elsif ($header->{'content-type'} &&
       $header->{'content-type'} =~ /text\/css/ &&
       !$header->{'x-no-links'}) {
	# Fix up CSS
	while($_ = &read_http_connection($con)) {
		s/url\("(\/[^"]*)"\)/url\("$url$1"\)/gi;
		print;
		}
	}
else {
	# Just pass through
	my $bs = &get_buffer_size();
	while(my $buf = &read_http_connection($con, $bs)) {
		print $buf;
		}
	}
&close_http_connection($con);

# register_link_websocket(url, &server, auth, \%cache)
# Registers a local miniserv websocket proxy for a websocket URL generated by
# the linked Webmin server, and returns the local URL for the browser to use.
sub register_link_websocket
{
my ($wsurl, $s, $auth, $cache) = @_;
# JSON script responses can encode wss:// as wss:\/\/. Normalize before
# matching, and restore the escaping style for the returned URL below.
my $escaped_slashes = $wsurl =~ /\\\//;
$wsurl =~ s#\\/#/#g;
my $host = $s->{'host'};
my $port = $s->{'port'};
my $ssl = $s->{'ssl'};
my $proto = $ssl ? "wss" : "ws";
my ($url_proto, $url_host, $url_port, $remote_path) =
	$wsurl =~ /^(wss?):\/\/(\[[^\]]+\]|[^:\/]+)(?::(\d+))?(\/[^'"]*)$/i;
return $wsurl if (!$remote_path || lc($url_proto) ne $proto);
return $wsurl if ($url_host =~ /[\s\x00-\x1f\x7f]/ ||
		  $remote_path =~ /[\s\x00-\x1f\x7f]/);
my $url_host_cmp = lc($url_host);
$url_host_cmp =~ s/^\[|\]$//g;
my @valid_hosts = grep { defined($_) && $_ ne "" } ($host, $s->{'ip'});
my $link_prefix = &get_webprefix()."/$module_name/link.cgi/$s->{'id'}";
my $from_link_path = $remote_path =~ s/^\Q$link_prefix\E//;
# Only websocket URLs owned by the linked server are proxied. Some themes
# build them with the link.cgi prefix already present; strip that prefix
# before registering the backend path.
return $wsurl if (!$from_link_path &&
		  !grep { lc($_) eq $url_host_cmp } @valid_hosts);
return $wsurl if (!$from_link_path && defined($url_port) &&
		  $url_port != $port);
my ($remote_port) = $remote_path =~ /\/ws-(\d+)(?:\?|$)/;
return $wsurl if (!$remote_port);
# Reuse the same local URL when a response repeats the same backend websocket.
# Otherwise the later rewrite would replace the config token for the earlier URL.
my $cache_key = join("\0", $s->{'id'}, $remote_path);
if ($cache && $cache->{$cache_key}) {
	my $rv = $cache->{$cache_key};
	$rv =~ s#/#\\/#g if ($escaped_slashes);
	return $rv;
	}

my $token = &generate_miniserv_websocket_token();
my $wspath = "/$module_name/ws-link-$s->{'id'}-$remote_port-$token";
my $now = time();
my $backend_host = $s->{'ip'} || $host;
my $defport = $ssl ? 443 : 80;
# If the URL was already routed through this parent link.cgi, its host is the
# parent server. Backend Host, Origin and TLS checks must use the child server.
my $hostheader = $from_link_path ? $host : $url_host;
$hostheader .= ":".$port if ($port != $defport);
my $origin = ($ssl ? "https" : "http")."://".$hostheader;
my $checkssl = $s->{'checkssl'} ? 1 : 0;
my %miniserv;
&lock_file(&get_miniserv_config_file());
&get_miniserv_config(\%miniserv);
$miniserv{"websockets_$wspath"} =
	"host=$backend_host port=$port ssl=$ssl wspath=$remote_path ".
	"hostheader=$hostheader origin=$origin auth=basic:$auth ".
	"checkssl=$checkssl nokey=1 user=$main::remote_user ".
	"token=$token time=$now";
&put_miniserv_config(\%miniserv);
&unlock_file(&get_miniserv_config_file());
&reload_miniserv();

# Pass the fresh token directly. Re-reading miniserv.conf here can race the
# config cache and return a stale token for the same ws-link path.
my $rv = &get_miniserv_websocket_url(
	undef, undef, $module_name, $wspath, $token);
$cache->{$cache_key} = $rv if ($cache);
$rv =~ s#/#\\/#g if ($escaped_slashes);
return $rv;
}

# cleanup_link_websockets()
# Removes abandoned websocket proxy routes created for linked Webmin servers.
# Active routes are removed by miniserv when their websocket tunnel closes.
sub cleanup_link_websockets
{
my %miniserv;
my $now = time();
my $changed = 0;
&lock_file(&get_miniserv_config_file());
&get_miniserv_config(\%miniserv);
foreach my $k (keys %miniserv) {
	next if ($k !~ /^websockets_\/\Q$module_name\E\/ws-link-/);
	my ($time) = $miniserv{$k} =~ /\btime=(\d+)/;
	if (!$time || $now - $time > 24*60*60) {
		delete($miniserv{$k});
		$changed++;
		}
	}
&put_miniserv_config(\%miniserv) if ($changed);
&unlock_file(&get_miniserv_config_file());
&reload_miniserv() if ($changed);
}
