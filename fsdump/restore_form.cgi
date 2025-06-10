#!/usr/local/bin/perl
# restore_form.cgi
# Display a form with restore options

require './fsdump-lib.pl';
&ReadParse();
$access{'restore'} || &error($text{'restore_ecannot'});

&ui_print_header(undef, $text{'restore_title'}, "", "restore");

$m = &missing_restore_command($in{'fs'}) if ($in{'fs'} ne 'tar');
if ($m) {
	print "<p>",&text('restore_ecommand', "<tt>$m</tt>", uc($in{'fs'})),
	      "<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}
if ($in{'id'}) {
	# Restoring a specific dump
	$dump = &get_dump($in{'id'});
	}

print "<b>$text{'restore_desc'}</b><p>\n";

@tds = ( "width=30%" );
print &ui_form_start("restore.cgi", "post");
print &ui_hidden("fs", $in{'fs'}),"\n";
print &ui_table_start($in{'fs'} eq 'tar' ? $text{'restore_theader'} :
			&text('restore_header', uc($in{'fs'})),
		      "width=100%", 4);

&restore_form($in{'fs'}, $dump, \@tds);

if ($access{'extra'}) {
	print &ui_table_row(&hlink($text{'restore_extra'}, "rextra"),
			    &ui_textbox("extra", undef, 60), 3, \@tds);
	}

print &ui_table_end();
print &ui_form_end([ [ "ok", $text{'restore_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});

