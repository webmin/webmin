#!/usr/bin/perl
# Show a config file for manual editing

require './spam-lib.pl';
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("manual");
&ui_print_header($header_subtext, $text{'manual_title'}, "");

$conf = &get_config();
@files = &unique(map { $_->{'file'} } @$conf);
push(@files, $config{'amavisdconf'}) if (!$warn_procmail && -r $config{'amavisdconf'});
$in{'manual'} ||= $files[0];
&indexof($in{'manual'}, @files) >= 0 ||
	&error($text{'manual_efile'});

# File selector
print &ui_form_start("edit_manual.cgi");
print $form_hiddens;
print "<b>$text{'manual_file'}</b>\n",
      &ui_select("manual", $in{'manual'}, \@files),"\n",
      &ui_submit('Edit');
print &ui_form_end();

# Config editor
print &ui_form_start("save_manual.cgi", "form-data");
print $form_hiddens;
print &ui_hidden("manual", $in{'manual'});
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef,
	&ui_textarea("data", &read_file_contents($in{'manual'}), 20, 80), 2);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
