#!/usr/local/bin/perl
# edit_mesg.cgi
# Edit subscription options

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
$conf = &get_list_config($list->{'config'});
$desc = &text('edit_for', "<tt>".&html_escape($in{'name'})."</tt>");
&ui_print_header($desc, $text{'mesg_title'}, "");

print "<form action=save_mesg.cgi>\n";
print "<input type=hidden name=name value='$in{'name'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'mesg_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr>\n";
print &opt_input("reply_to", $text{'mesg_reply'},
		 $conf, $text{'mesg_none'}, 20);
print &opt_input("sender", $text{'mesg_sender'}, $conf,
		 $text{'default'}, 15);
print "</tr>\n";

print "<tr>\n";
print &opt_input("resend_host", $text{'mesg_host'}, $conf,
		 $text{'default'}, 15);
print &opt_input("subject_prefix", $text{'mesg_subject'},
		 $conf, $text{'default'}, 20);
print "</tr>\n";

print "<tr>\n";
print &select_input("precedence", $text{'mesg_precedence'}, $conf,
		    "first-class", $text{'mesg_first'},
		    "special-delivery", $text{'mesg_special'},
		    "list", $text{'mesg_list'},
		    "bulk", $text{'mesg_bulk'},
		    "junk", $text{'mesg_junk'});
print &choice_input("purge_received", $text{'mesg_purge'}, $conf,
		    "yes", $text{'yes'}, "no", $text{'no'});
print "</tr>\n";

print "<tr>\n";
print &opt_input("maxlength", $text{'mesg_maxlength'}, $conf,
		 $text{'default'}, 8, "bytes");
print "</tr>\n";

print "</table></td></tr></table>\n";
print &ui_submit($text{'save'}),"</form>\n";

&ui_print_footer("edit_list.cgi?name=$in{'name'}", $text{'edit_return'});

