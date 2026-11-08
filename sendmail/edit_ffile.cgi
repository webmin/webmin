#!/usr/local/bin/perl
# edit_ffile.cgi
# Allow editing of a filter config file

require (-r 'sendmail-lib.pl' ? './sendmail-lib.pl' :
	 -r 'qmail-lib.pl' ? './qmail-lib.pl' :
			     './postfix-lib.pl');
&ReadParse();
if (!&is_under_directory($access{'apath'}, $in{'file'})) {
	&error(&text('ffile_efile', $in{'file'}));
	}

&ui_print_header(undef, $text{'ffile_title'}, "");
&open_readfile(FILE, $in{'file'});
while(<FILE>) {
	s/\r|\n//g;
	if (/^(\S+)\s+(\S+)\s+(\S+)\s+(.*)$/) {
		push(@filter, [ $1, $2, $3, $4 ]);
		}
	elsif (/^(2)\s+(\S+)$/) {
		$other = $2;
		}
	}
close(FILE);

print "<b>",&text('ffile_desc',
		  "<tt>".&html_escape($in{'file'})."</tt>"),"</b><p>\n";

print &ui_form_start("save_ffile.cgi", "form-data");
print &ui_hidden("file", $in{'file'});
print &ui_hidden("num", $in{'num'});
print &ui_hidden("name", $in{'name'});

$i = 0;
foreach $f (@filter, [ 1, '', '', '' ],
		     [ 1, '', '', '' ],
		     [ 1, '', '', '' ],
		     [ 1, '', '', '' ],
		     [ 1, '', '', '' ]) {
	$field = &ui_select("field_$i", $f->[2],
		[ map { [ $_, $text{'ffile_'.$_} ] }
		      ('', 'from', 'to', 'subject', 'cc', 'body') ])."\n";

	$what = &ui_select("what_$i", $f->[0],
			   [ [ 0, $text{'ffile_what0'} ],
			     [ 1, $text{'ffile_what1'} ] ]);

	$match = &ui_textbox("match_$i", $f->[3], 20)."\n";

	$action = &ui_textbox("action_$i", $f->[1], 30)."\n";

	print &text('ffile_line', $field, $what, $match, $action),"<br>\n";
	$i++;
	}
print &text('ffile_other', &ui_textbox("other", $other, 30)),"<br>\n";

print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("edit_alias.cgi?name=".&urlize($in{'name'}).
		 "&num=".&urlize($in{'num'}), $text{'aform_return'});

