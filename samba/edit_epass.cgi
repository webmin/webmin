#!/usr/local/bin/perl
# edit_epass.cgi
# Display a list of samba users for editing

require './samba-lib.pl';
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pvusers'}")
        unless $access{'view_users'};
# display
&ui_print_header(undef, $text{'smbuser_title'}, "");

&check_user_enabled($text{'smbuser_cannot'});

@ulist = &list_users();
@ulist = sort { $a->{'name'} cmp $b->{'name'} } @ulist
	if ($config{'sort_mode'});
if (@ulist) {
	@grid = ( );
	for($i=0; $i<@ulist; $i++) {
		$u = $ulist[$i];
		push(@grid, &ui_link("edit_euser.cgi?idx=$u->{'index'}",&html_escape($u->{'name'})));
		}
	print &ui_grid_table(\@grid, 4, 100,
		[ "width=25%", "width=25%", "width=25%", "width=25%" ],
		undef, $text{'smbuser_list'});
	}
else {
	print "<b>$text{'smbuser_nouser'}</b> <p>\n";
	}

&ui_print_footer("", $text{'index_sharelist'});
