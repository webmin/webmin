#!/usr/local/bin/perl
# Show a form for mounting or un-mounting one volume

require './bacula-backup-lib.pl';
&ui_print_header(undef,  $text{'mount_title'}, "", "mount");

print &ui_form_start("mount.cgi", "post");
print &ui_table_start($text{'mount_header'}, undef, 2);

# Storage to mount
@storages = sort { lc($a->{'name'}) cmp lc($b->{'name'}) }
		 &get_bacula_storages();
print &ui_table_row($text{'mount_storage'},
	&ui_select("storage", $in{'storage'},
	 [ map { [ $_->{'name'},
		   &text('clientstatus_on', $_->{'name'}, $_->{'address'}) ] }
	   @storages ]));

# Autoloader slot
print &ui_table_row($text{'mount_slot'},
	&ui_opt_textbox("slot", undef, 5, $text{'mount_noslot'},
			$text{'mount_slotno'}));

print &ui_table_end();
print &ui_form_end([ [ 'mount', $text{'mount_mount'} ],
		     [ 'unmount', $text{'mount_unmount'} ] ]);

&ui_print_footer("", $text{'index_return'});
