#!/usr/local/bin/perl
# edit_sync.cgi
# Display options for the automatic setting up of SSH for new users

require './sshd-lib.pl';
&ui_print_header(undef, $text{'sync_title'}, "");

print "<form action=save_sync.cgi>\n";
print "$text{'sync_desc'}<p>\n";

$sp = "&nbsp;" x 5;

print &ui_checkbox("create", 1, $text{'sync_create'}, $config{'sync_create'}),
      "<br>\n";
print $sp,&ui_checkbox("auth", 1, $text{'sync_auth'}, $config{'sync_auth'}),
      "<br>\n";
print $sp,&ui_checkbox("pass", 1, $text{'sync_pass'}, $config{'sync_pass'}),
      "<br>\n";
print $sp,$text{'sync_type'}," ",
      &ui_select("type", $config{'sync_type'},
		 [ [ "", $text{'sync_auto'} ],
		   [ "rsa" ], [ "dsa" ], [ "rsa1" ] ]),"<br>\n";

print "<input type=submit value='$text{'save'}'></form>\n";
&ui_print_footer("", $text{'index_return'});

