#!/usr/local/bin/perl
# swat.cgi
# Pass everything to samba's SWAT tool

require './samba-lib.pl';
&ReadParse();

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcswat'}") unless $access{'swat'};

# Check is hosts allow is in force
&get_share("global");
if (&getval('allow hosts')) {
	&ui_print_header(undef, $text{'error'}, "");
	print &text('swat_msg3', $text{'sec_onlyallow'}), "<p>\n";
	&foreign_require("inetd", "inetd-lib.pl");
	local @inets = &foreign_call("inetd", "list_inets");
	foreach $i (@inets) {
		if ($i->[3] eq 'swat' && $i->[1]) {
			# swat is configured in inetd!
			local $p = getservbyname('swat', 'tcp');
			$url = "http://$ENV{'SERVER_NAME'}:$p/";
			print &text('swat_msg4', "<a href='$url'>$url</a>"), "<p>\n";
			}
		}
	&ui_print_footer("", $text{'index_sharelist'});
	exit;
	}

# Check if we have the password
&read_file("$module_config_directory/swat", \%swat) || &ask_password();

# Execute SWAT process
pipe(OUTr, OUTw);
pipe(INr, INw);
local $pid = fork();
if (!$pid) {
	untie(*STDIN);
	untie(*STDOUT);
	untie(*STDERR);
	open(STDIN, "<&INr");
	open(STDOUT, ">&OUTw");
	open(STDERR, ">&OUTw");
	close(OUTr); close(INw);
	undef %ENV;
	exec($config{'swat_path'});
	print "Exec failed : $!\n";
	exit 1;
	}
close(OUTw); close(INr);

# Feed HTTP request and read output
$auth = &encode_base64("$swat{'user'}:$swat{'pass'}");
$auth =~ s/\n//g;
select(INw); $| = 1; select(STDOUT);
$path = $ENV{'PATH_INFO'} || "/";
if ($ENV{'REQUEST_METHOD'} eq 'GET') {
	print INw "GET $path?$in HTTP/1.0\n";
	print INw "Authorization: basic $auth\n";
	print INw "\n";
	}
else {
	print INw "POST $path HTTP/1.0\r\n";
	print INw "Authorization: basic $auth\r\n";
	print INw "Content-length: ",length($in),"\r\n";
	print INw "Content-type: application/x-www-form-urlencoded\r\n";
	print INw "\r\n",$in;
	}
close(INw);
$reply = <OUTr>;
if ($reply =~ /\s401\s/) {
	&ask_password();
	}
if ($ENV{'PATH_INFO'} =~ /\.(gif|jpg|jpeg|png)$/i) {
	# An image .. just output it
	while(<OUTr>) { print; }
	}
else {
	# An HTML page .. fix up links
	$url = "$gconfig{'webprefix'}/$module_name/swat.cgi";
	while(<OUTr>) {
		s/src="(\/[^"]*)"/src="$url$1"/gi;
		s/href="(\/[^"]*)"/href="$url$1"/gi;
		s/action="(\/[^"]*)"/action="$url$1"/gi;
		s/"(\/status?[^"]*)"/"$url$1"/gi;
		print $_ if (!/<\/body>/i && !/<\/html>/i);
		}
	print "<table width=100% cellpadding=0 cellspacing=0><tr><td>\n";
	&ui_print_footer("/$module_name/", $text{'index_sharelist'}, 1);
	print "</td> <td align=right><a href='/$module_name/logout.cgi'>",
	      "$text{'swat_logout'}</a></td> </tr></table></body></html>\n";
	}

sub ask_password
{
&ui_print_header(undef, $text{'swat_title'}, "");
if (%swat) {
	print $text{'swat_msg1'}, " <br>\n";
	}
else {
	print $text{'swat_msg2'}, " <br>\n";
	}
print "<form action=swat_save.cgi>\n";
print "<center><table border>\n";
print "<tr $tb> <td><b>$text{'swat_list'}</b></td> </tr>\n";
print "<tr $cb> <td><table cellpadding=2>\n";
print "<tr> <td><b>$text{'swat_username'}</b></td>\n";
print "<td><input name=user size=20 value='$swat{'user'}'></td> </tr>\n";
print "<tr> <td><b>$text{'swat_password'}</b></td>\n";
print "<td><input name=pass size=20 type=password></td> </tr>\n";
print "</table></td></tr></table>\n";
print "<input type=submit value=\"", $text{'swat_login'},
      "\"> <input type=reset value=\"", $text{'swat_clear'}, "\">\n";
print "</center></form>\n";
&ui_print_footer("", $text{'index_sharelist'});
exit;
}

