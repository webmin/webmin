#!/usr/local/bin/perl
# save_afile.cgi
# Save an addresses file

require (-r 'sendmail-lib.pl' ? './sendmail-lib.pl' :
	 -r 'qmail-lib.pl' ? './qmail-lib.pl' :
			     './postfix-lib.pl');
&ReadParseMime();
if (substr($in{'file'}, 0, length($access{'apath'})) ne $access{'apath'}) {
	&error(&text('afile_efile', $in{'file'}));
	}

$in{'text'} =~ s/\r//g;
$in{'text'} =~ s/\n*$/\n/;
&open_lock_tempfile(FILE, ">$in{'file'}", 1) || &error(&text('afile_ewrite', $!));
&print_tempfile(FILE, $in{'text'});
&close_tempfile(FILE);
&redirect("edit_alias.cgi?name=$in{'name'}&num=$in{'num'}");

