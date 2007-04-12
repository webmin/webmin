#!/usr/local/bin/perl
# Delete all mail in some mailbox, after asking for confirmation

require './mailboxes-lib.pl';
&ReadParse();
&can_user($in{'user'}) || &error($text{'mail_ecannot'});
&is_user($in{'user'}) || -e $in{'user'} || &error($text{'mail_efile'});
@folders = &list_user_folders_sorted($in{'user'});
($folder) = grep { $_->{'index'} == $in{'folder'} } @folders;

if ($in{'confirm'}) {
	# Do it!
	$sz = &mailbox_folder_size($folder);
	&mailbox_empty_folder($folder);
	&webmin_log("delmail", undef, undef, { 'from' => $folder->{'file'},
					       'count' => $sz });
	&redirect("list_mail.cgi?user=$in{'user'}&folder=$in{'folder'}");
	}
else {
	# Ask first
	&ui_print_header(undef, $text{'delall_title'}, "");
	print &ui_form_start("delete_all.cgi");
	print &ui_hidden("user", $in{'user'}),"\n";
	print &ui_hidden("folder", $in{'folder'}),"\n";
	print "<center>\n";
	print &text('delall_rusure',
		    "<tt>$folder->{'file'}</tt>",
		    &mailbox_folder_size($folder), 
		    &nice_size(&folder_size($folder))),"<p>\n";
	print &ui_submit($text{'delall_ok'}, "confirm"),"\n";
	print &ui_form_end();
	print "</center>\n";
	&ui_print_footer("list_mail.cgi?user=$in{'user'}&folder=$in{'folder'}",
			 $text{'mail_return'},
			 "", $text{'index_return'});
	}


