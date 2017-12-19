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
my $url = "$gconfig{'webprefix'}/$module_name/link.cgi/$s->{'id'}";
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
			"$gconfig{'webprefix'}/$module_name/login.cgi", "post");
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
			"Webmin-servers: %s://%s:%d/%s\n",
			$http_prot, $http_host, $http_port,
			$tconfig{'inframe'} ? "" : "$module_name/"));
&write_http_connection($con, sprintf(
			"Webmin-path: %s://%s:%d/%s/link.cgi%s\n",
			$http_prot, $http_host, $http_port,
			$module_name, $ENV{'PATH_INFO'}));
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
my (%header, $headers);
while(1) {
	my $headline;
	($headline = &read_http_connection($con)) =~ s/\r|\n//g;
	last if (!$headline);
	$headline =~ /^(\S+):\s+(.*)$/ || &error("Bad header");
	$header{lc($1)} = $2;
	$headers .= $headline."\n";
	}

my $defport = $s->{'ssl'} ? 443 : 80;
if ($header{'location'} &&
    ($header{'location'} =~ /^(http|https):\/\/$s->{'host'}:$s->{'port'}(.*)$/||
     $header{'location'} =~ /^(http|https):\/\/$s->{'host'}(.*)/ &&
     $s->{'port'} == $defport)) {
	# fix a redirect
	local $gconfig{'webprefixnoredir'} = 1;		# We've already added
							# webprefix, so no need
							# to add it again
	&redirect("$url$2");
	exit;
	}
elsif ($header{'www-authenticate'}) {
	# Invalid login
	if ($s->{'autouser'}) {
		print "Set-Cookie: $id=; path=/\n";
		&error(&text('link_eautologin', $s->{'host'},
		     "$gconfig{'webprefix'}/$module_name/link.cgi/$id/"));
		}
	else {
		&error(&text('link_elogin', $s->{'host'}, $user));
		}
	}
else {
	# just output the headers
	print $headers,"\n";
	}

# read back the rest of the page
if ($header{'content-type'} =~ /text\/html/ && !$header{'x-no-links'}) {
	# Fix up HTML
	while($_ = &read_http_connection($con)) {
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
		print;
		if (/<applet.*archive=file.jar.*>/) {
			# Remote webmin file manager applet - give it the 
			# session ID on *this* system
			print "<param name=session value=\"$main::session_id\">\n";
			}
		}
	}
elsif ($header{'content-type'} =~ /text\/css/ && !$header{'x-no-links'}) {
	# Fix up CSS
	while($_ = &read_http_connection($con)) {
		s/url\("(\/[^"]*)"\)/url\("$url$1"\)/gi;
		print;
		}
	}
else {
	# Just pass through
	while(my $buf = &read_http_connection($con, 1024)) {
		print $buf;
		}
	}
&close_http_connection($con);

