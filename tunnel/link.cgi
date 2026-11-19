#!/usr/local/bin/perl
# link.cgi
# Forward the URL from path_info on to another webmin server

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%config, %text, %module_info, %in, %gconfig, $module_name);
require './tunnel-lib.pl';

$ENV{'PATH_INFO'} =~ /^\/(http|https):\/+([^:\/]+)(:(\d+))?(.*)$/ ||
	&error("Bad PATH_INFO : ".&html_escape($ENV{'PATH_INFO'}));
my $protocol = $1;
my $ssl = $protocol eq "https";
my $host = $2;
my $port = $4 || ( !$ssl ? 80 : 443 );
my $path = $5 || "/";
my $openurl = "$1://$2$3$5";
my $baseurl = "$1://$2$3";
if ($ENV{'QUERY_STRING'}) {
	$path .= '?'.$ENV{'QUERY_STRING'};
	}
elsif (@ARGV) {
	$path .= '?'.join('+', @ARGV);
	}
my $linkurl = &get_webprefix()."/$module_name/link.cgi/";
my $url = &get_webprefix()."/$module_name/link.cgi/$openurl";
$| = 1;
my $meth = $ENV{'REQUEST_METHOD'};
if ($config{'url'}) {
	$openurl = &fix_end_url($config{'url'}) || &error($text{'seturl_eurl'});
	}

my ($user, $pass);
if ($config{'loginmode'} == 2) {
	# Login is variable .. check if we have it yet
	if ($ENV{'HTTP_COOKIE'} =~ /tunnel=([^\s;]+)/) {
		# Yes - set the login and password to use
		($user, $pass) = split(/:/, &decode_base64("$1"));
		}
	else {
		# No - need to display a login form
		&ui_print_header(undef, $text{'login_title'}, "");

		print "<center>\n";
		print &text('login_desc', "<tt>$openurl</tt>"),"<p>\n";

		print &ui_form_start("/$module_name/login.cgi", "post");
		print &ui_hidden("url", $openurl);
		print &ui_table_start($text{'login_header'}, undef, 2);
		print &ui_table_row($text{'login_user'},
			&ui_textbox("user", undef, 20));
		print &ui_table_row($text{'login_pass'},
			&ui_password("pass", undef, 20));
		print &ui_table_end();
		print &ui_form_end([ [ undef, $text{'login_login'} ] ]);

		print "</center>\n";

		&ui_print_footer("", $text{'index_return'});
		exit;
		}
	}
elsif ($config{'loginmode'} == 1) {
	# Login is fixed
	$user = $config{'user'};
	$pass = $config{'pass'};
	}

# Connect to the server
my $con = &make_http_connection($host, $port, $ssl, $meth, $path);
&error($con) if (!ref($con));

# Send request headers
&write_http_connection($con, "Host: $host\r\n");
&write_http_connection($con, "User-Agent: Webmin\r\n");
if ($user) {
	my $auth = &encode_base64("$user:$pass");
	$auth =~ s/\n//g;
	&write_http_connection($con, "Authorization: basic $auth\r\n");
	}
&write_http_connection($con, sprintf(
			"Webmin-servers: %s://%s:%d/$module_name/\r\n",
			$ENV{'HTTPS'} eq "ON" ? "https" : "http",
			$ENV{'SERVER_NAME'}, $ENV{'SERVER_PORT'}));
my $cl = $ENV{'CONTENT_LENGTH'};
&write_http_connection($con, "Content-Length: $cl\r\n") if ($cl);
&write_http_connection($con, "Content-Type: $ENV{'CONTENT_TYPE'}\r\n")
	if ($ENV{'CONTENT_TYPE'});
&write_http_connection($con, "\r\n");
if ($cl) {
	my $post;
	&read_fully(\*STDIN, \$post, $cl);
	&write_http_connection($con, $post);
	}

# read back the headers
my $dummy = &read_http_connection($con);
my ($headers, %header);
while(1) {
	my $headline;
	($headline = &read_http_connection($con)) =~ s/\r|\n//g;
	last if (!$headline);
	$headline =~ /^(\S+):\s+(.*)$/ || &error("Bad header");
	$header{lc($1)} = $2;
	$headers .= $headline."\n";
	}

my $defport = $ssl ? 443 : 80;
if ($header{'location'}) {
	# fix a redirect
	&redirect("/$module_name/link.cgi/$header{'location'}");
	exit;
	}
if ($header{'location'} =~ /^(http|https):\/\/$host:$port$path(.*)$/ ||
    $header{'location'} =~ /^(http|https):\/\/$host$path(.*)/ &&
    $port == $defport) {
	# fix a redirect
	&redirect("$url/$2");
	exit;
	}
elsif ($header{'www-authenticate'}) {
	# Invalid login
	if ($config{'loginmode'} == 2) {
		print "Set-Cookie: tunnel=; path=/\n";
		&error(&text('link_eautologin', "<tt>$openurl</tt>",
		     "/$module_name/link.cgi/$path"));
		}
	elsif ($user) {
		&error(&text('link_elogin', $host, $user)." ".
		       &text('link_mconfig',
			"@{[&get_webprefix()]}/config.cgi?$module_name"));
		}
	else {
		&error(&text('link_enouser', $host)." ".
		       &text('link_mconfig',
			"@{[&get_webprefix()]}/config.cgi?$module_name"));
		}
	}
else {
	# just output the headers
	print $headers,"\n";
	}

# read back the rest of the page
if ($header{'content-type'} =~ /text\/html/ && !$header{'x-no-links'}) {
	while($_ = &read_http_connection($con)) {
		# fix protocol relative src like <iframe src='//foo.com' />
		s/src='(\/\/[^']*)'/src='$protocol:$1'/gi;
		s/src="(\/\/[^"]*)"/src="$protocol:$1"/gi;
		s/src=(\/\/[^ "'>]*)/src=$protocol:$1/gi;

		# Fix protocol relative hrefs like <a href=//foo.com/foo.html>
		s/href='(\/\/[^']*)'/href='$protocol:$1'/gi;
		s/href="(\/\/[^"]*)"/href="$protocol:$1"/gi;
		s/href=(\/\/[^ "'>]*)/href=$protocol:$1/gi;

		# Fix protocol relative form actions like <form action=//foo.com>
		s/action='(\/\/[^']*)'/action='$protocol:$1'/gi;
		s/action="(\/\/[^"]*)"/action="$protocol:$1"/gi;
		s/action=(\/\/[^ "'>]*)/action=$protocol:$1/gi;

		# Fix absolute image links like <img src=/foo.gif>
		s/src='(\/[^']*)'/src='$baseurl$1'/gi;
		s/src="(\/[^"]*)"/src="$baseurl$1"/gi;
		s/src=(\/[^ "'>]*)/src=$baseurl$1/gi;

		# Fix offsite image links <img src=http://www.blah.com/foo.gif>
		s/src='((http|https):\/\/[^']*)'/src='$linkurl$1'/gi;
		s/src="((http|https):\/\/[^"]*)"/src="$linkurl$1"/gi;
		s/src=((http|https):\/\/[^ "'>]*)/src=$linkurl$1/gi;

		# Fix absolute hrefs like <a href=/foo.html>
		s/href='(\/[^']*)'/href='$baseurl$1'/gi;
		s/href="(\/[^"]*)"/href="$baseurl$1"/gi;
		s/href=(\/[^ "'>]*)/href=$baseurl$1/gi;

		# Fix offsite hrefs like <a href=http://www.blah.com/>
		s/href='((http|https):\/\/[^']*)'/href='$linkurl$1'/gi;
		s/href="((http|https):\/\/[^"]*)"/href="$linkurl$1"/gi;
		s/href=((http|https):\/\/[^ "'>]*)/href=$linkurl$1/gi;

		# Fix absolute form actions like <form action=/foo>
		s/action='(\/[^']*)'/action='$baseurl$1'/gi;
		s/action="(\/[^"]*)"/action="$baseurl$1"/gi;
		s/action=(\/[^ "'>]*)/action=$baseurl$1/gi;

		# Fix offsite form actions
		s/action='((http|https):\/\/[^']*)'/action='$linkurl$1'/gi;
		s/action="((http|https):\/\/[^"]*)"/action="$linkurl$1"/gi;
		s/action=((http|https):\/\/[^ "'>]*)/action=$linkurl$1/gi;

		#s/\.location\s*=\s*'$path([^']*)'/.location='$url\/$1'/gi;
		#s/\.location\s*=\s*"$path([^']*)"/.location="$url\/$1"/gi;
		#s/window.open\("$path([^"]*)"/window.open\("$url\/$1"/gi;
		#s/name=return\s+value="$path([^"]*)"/name=return value="$url\/$1"/gi;
		print;
		}
	}
else {
	while(my $buf = &read_http_connection($con,1024)) {
		print $buf;
		}
	}
&close_http_connection($con);

