#!/usr/local/bin/perl
# edit_feature.cgi
# Displays a form for editing or creating some M4 file entry, which may be a
# feature, define, mailer or other line.

require './sendmail-lib.pl';
require './features-lib.pl';
&ReadParse();
$features_access || &error($text{'features_ecannot'});

if ($in{'manual'}) {
	# Display manual edit form
	&ui_print_header(undef, $text{'feature_manual'}, "");

	print &ui_form_start("manual_features.cgi", "form-data");
	print &text('feature_mdesc', "<tt>$config{'sendmail_mc'}</tt>"),
	      "<br>\n";
	print &ui_textarea("data", &read_file_contents($config{'sendmail_mc'}),
			   20, 80);
	print &ui_form_end([ [ undef, $text{'save'} ] ]);

	&ui_print_footer("list_features.cgi", $text{'features_return'});
	exit;
	}
if ($in{'new'}) {
	&ui_print_header(undef, $text{'feature_add'}, "");
	$feature = { 'type' => $in{'type'} };
	}
else {
	&ui_print_header(undef, $text{'feature_edit'}, "");
	@features = &list_features();
	$feature = $features[$in{'idx'}];
	}

print &ui_form_start("save_feature.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("type", $feature->{'type'});
print &ui_table_start($text{'feature_header'}, "width=100%", 2);

# Current value
if (!$in{'new'} && $feature->{'type'}) {
	print &ui_table_row($text{'feature_old'},
		"<tt>".&html_escape($feature->{'text'})."</tt>");
	}

if ($feature->{'type'} == 0) {
	# Unsupported text line
	print &ui_table_row($text{'feature_text'},
		&ui_textbox("text", $feature->{'text'}, 80));
	}
elsif ($feature->{'type'} == 1) {
	# A FEATURE() definition
	print &ui_table_row($text{'feature_feat'},
		&ui_select("name", $feature->{'name'},
			   [ &list_feature_types() ]));

	local @v = @{$feature->{'values'}};
	@v = ( "" ) if (!@v);
	local @vals;
	for($i=0; $i<=@v; $i++) {
		push(@vals, &ui_textbox("value_$i", $v[$i], 50));
		}
	print &ui_table_row($text{'feature_values'},
		join("<br>\n", @vals));
	}
elsif ($feature->{'type'} == 2 || $feature->{'type'} == 3) {
	# A define() or undefine()
	print &ui_table_row($text{'feature_def'},
		&ui_select("name", $feature->{'name'},
			   [ &list_define_types() ], 1, 0, 1));

	print &ui_table_row($text{'feature_defval'},
		&ui_radio("undef", $feature->{'type'} == 2 ? 0 : 1,
			  [ [ 0, $text{'feature_defmode1'}." ".
			      &ui_textbox("value", $feature->{'value'}, 50) ],
			    [ 1, $text{'feature_defmode0'} ] ]));
	}
elsif ($feature->{'type'} == 4) {
	# A MAILER() definition
	print &ui_table_row($text{'feature_mailer'},
		&ui_select("mailer", $feature->{'mailer'},
			   [ &list_mailer_types() ]));
	}
elsif ($feature->{'type'} == 5) {
	# An OSTYPE() definition
	print &ui_table_row($text{'feature_ostype'},
		&ui_select("ostype", $feature->{'ostype'},
			   [ &list_ostype_types() ]));
	}

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_features.cgi", $text{'features_return'});

