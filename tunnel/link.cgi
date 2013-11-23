#!/usr/local/bin/perl
# link.cgi
# Forward the URL from path_info on to another webmin server

require './tunnel-lib.pl';
#$ENV{'PATH_INFO'} =~ /^\/(.*)$/ ||
#	&error("Bad PATH_INFO : $ENV{'PATH_INFO'}");
$ENV{'PATH_INFO'} =~ /^\/(http|https):\/+([^:\/]+)(:(\d+))?(.*)$/ ||
	&error("Bad PATH_INFO : $ENV{'PATH_INFO'}");
$protocol = $1;
$ssl = $protocol eq "https";
$host = $2;
$port = $4 || ( !$ssl ? 80 : 443 );
$path = $5 || "/";
$openurl = "$1://$2$3$5";
$baseurl = "$1://$2$3";
if ($ENV{'QUERY_STRING'}) {
	$path .= '?'.$ENV{'QUERY_STRING'};
	}
elsif (@ARGV) {
	$path .= '?'.join('+', @ARGV);
	}
$linkurl = $gconfig{'webprefix'}."/$module_name/link.cgi/";
$url = $gconfig{'webprefix'}."/$module_name/link.cgi/$openurl";
$| = 1;
$meth = $ENV{'REQUEST_METHOD'};
if ($config{'url'}) {
	$openurl =~ /^\Q$config{'url'}\E/ ||
		&error(&text('link_ebadurl', $openurl));
    $openurl = &fix_end_url($openurl) || &error($text{'seturl_eurl'});
	}

if ($config{'loginmode'} == 2) {
	# Login is variable .. check if we have it yet
	if ($ENV{'HTTP_COOKIE'} =~ /tunnel=([^\s;]+)/) {
		# Yes - set the login and password to use
		($user, $pass) = split(/:/, &decode_base64("$1"));
		}
	else {
		# No - need to display a login form
		&ui_print_header(undef, $text{'login_title'}, "");

		print "<center>",&text('login_desc', "<tt>$openurl</tt>"),
		      "</center><p>\n";
		print "<form action=/$module_name/login.cgi method=post>\n";
		print "<input type=hidden name=url value='",
			&html_escape($openurl),"'>\n";
		print "<center><table border>\n";
		print "<tr $tb> <td><b>$text{'login_header'}</b></td> </tr>\n";
		print "<tr $cb> <td><table cellpadding=2>\n";
		print "<tr> <td><b>$text{'login_user'}</b></td>\n";
		print "<td><input name=user size=20></td> </tr>\n";
		print "<tr> <td><b>$text{'login_pass'}</b></td>\n";
		print "<td><input name=pass size=20 type=password></td>\n";
		print "</tr> </table></td></tr></table>\n";
		print "<input type=submit value='$text{'login_login'}'>\n";
		print "<input type=reset value='$text{'login_clear'}'>\n";
		print "</center></form>\n";

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
$con = &make_http_connection($host, $port, $ssl, $meth, $path);
&error($con) if (!ref($con));

# Send request headers
&write_http_connection($con, "Host: $host\r\n");
&write_http_connection($con, "User-Agent: Webmin\r\n");
if ($user) {
	$auth = &encode_base64("$user:$pass");
	$auth =~ s/\n//g;
	&write_http_connection($con, "Authorization: Basic $auth\r\n");
	}
&write_http_connection($con, sprintf(
			"Webmin-servers: %s://%s:%d/$module_name/\n",
			$ENV{'HTTPS'} eq "ON" ? "https" : "http",
			$ENV{'SERVER_NAME'}, $ENV{'SERVER_PORT'}));
$cl = $ENV{'CONTENT_LENGTH'};
&write_http_connection($con, "Content-Length: $cl\r\n") if ($cl);
&write_http_connection($con, "Content-Type: $ENV{'CONTENT_TYPE'}\r\n")
	if ($ENV{'CONTENT_TYPE'});
&write_http_connection($con, "\r\n");
if ($cl) {
	&read_fully(STDIN, \$post, $cl);
	&write_http_connection($con, $post);
	}

# read back the headers
$dummy = &read_http_connection($con);
while(1) {
	($headline = &read_http_connection($con)) =~ s/\r|\n//g;
	last if (!$headline);
	$headline =~ /^(\S+):\s+(.*)$/ || &error("Bad header");
	$header{lc($1)} = $2;
	$headers .= $headline."\n";
	}

$defport = $ssl ? 443 : 80;
if ($header{'location'}) {
	# fix a redirect
	&redirect("/$module_name/link.cgi/$header{'location'}");
	exit;
	}
if ($header{'location'} =~ /^(http|https):\/\/$host:$port$page(.*)$/ ||
    $header{'location'} =~ /^(http|https):\/\/$host$page(.*)/ &&
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
		&error(&text('link_elogin', $host, $user));
		}
	else {
		&error(&text('link_enouser', $host));
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

		#s/\.location\s*=\s*'$page([^']*)'/.location='$url\/$1'/gi;
		#s/\.location\s*=\s*"$page([^']*)"/.location="$url\/$1"/gi;
		#s/window.open\("$page([^"]*)"/window.open\("$url\/$1"/gi;
		#s/name=return\s+value="$page([^"]*)"/name=return value="$url\/$1"/gi;
		print;
		}
	}
else {
	while($buf = &read_http_connection($con,1024)) {
		print $buf;
		}
	}
&close_http_connection($con);

