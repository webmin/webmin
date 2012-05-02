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
print "<center>\n";
print &ui_form_start("swat_save.cgi");
print &ui_table_start($text{'swat_list'}, undef, 2);

print &ui_table_row($text{'swat_username'},
	&ui_textbox("user", $swat{'user'}, 20));

print &ui_table_row($text{'swat_password'},
	&ui_password("pass", undef, 20));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'swat_login'} ] ]);
print "</center>\n";

&ui_print_footer("", $text{'index_sharelist'});
exit;
}

