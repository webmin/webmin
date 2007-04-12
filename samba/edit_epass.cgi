#!/usr/local/bin/perl
# edit_epass.cgi
# Display a list of samba users for editing

require './samba-lib.pl';
# check acls
%access = &get_module_acl();
&error_setup("<blink><font color=red>$text{'eacl_aviol'}</font></blink>");
&error("$text{'eacl_np'} $text{'eacl_pvusers'}")
        unless $access{'view_users'};
# display
&ui_print_header(undef, $text{'smbuser_title'}, "");

&check_user_enabled($text{'smbuser_cannot'});

@ulist = &list_users();
@ulist = sort { $a->{'name'} cmp $b->{'name'} } @ulist
	if ($config{'sort_mode'});
if (@ulist) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'smbuser_list'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	for($i=0; $i<@ulist; $i++) {
		$u = $ulist[$i];
		if ($i%4 == 0) { print "<tr>\n"; }
		print "<td width=25%><a href='edit_euser.cgi?idx=$u->{'index'}'>",&html_escape($u->{'name'}),"</a></td>\n";
		if ($i%4 == 3) { print "</tr>\n"; }
		}
	while($i++%4) {
		print "<td width=25%></td>\n";
		}
	print "</table></td> </tr></table><p>\n";
	}
else {
	print "<b>$text{'smbuser_nouser'}</b> <p>\n";
	}

&ui_print_footer("", $text{'index_sharelist'});
