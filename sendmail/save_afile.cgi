#!/usr/local/bin/perl
# save_afile.cgi
# Save an addresses file

require (-r 'sendmail-lib.pl' ? './sendmail-lib.pl' :
	 -r 'qmail-lib.pl' ? './qmail-lib.pl' :
			     './postfix-lib.pl');
&ReadParseMime();

# Needs permission for address file aliases, and for the file's directory
if (!&can_edit_alias_files(2, $in{'file'}) ||
    !&is_under_directory($access{'apath'}, $in{'file'})) {
	&error(&text('afile_efile', &html_escape($in{'file'})));
	}

$in{'text'} =~ s/\r//g;
$in{'text'} =~ s/\n*$/\n/;
&open_lock_tempfile(FILE, ">$in{'file'}", 1) || &error(&text('afile_ewrite', $!));
&print_tempfile(FILE, $in{'text'});
&close_tempfile(FILE);
&redirect("edit_alias.cgi?name=$in{'name'}&num=$in{'num'}");

