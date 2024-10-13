#!/usr/local/bin/perl
# Show disabled functions

require './phpini-lib.pl';
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$conf = &get_config($in{'file'});

&ui_print_header("<tt>$in{'file'}</tt>", $text{'disable_title'}, "");

print &ui_form_start("save_disable.cgi", "post");
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_table_start($text{'disable_header'}, "width=100%", 2);

# Disabled functions
@disfunc = split(/\s*,\s*/, &find_value("disable_functions", $conf));
@kfuncs = &list_known_disable_functions();
$dtable = "";
foreach my $f (@kfuncs) {
	$dtable .= &ui_checkbox("disable_functions", $f,
				$text{'disable_'.$f} || $f,
				&indexof($f, @disfunc) >= 0)."<br>\n";
	}
@leftover = grep { &indexof($_, @kfuncs) < 0 } @disfunc;
$dtable .= &ui_checkbox("disable_leftover", 1, $text{'disable_leftover'},
			@leftover ? 1 : 0)."\n".
	   &ui_textbox("leftover", join(",", @leftover), 60);
print &ui_table_row($text{'disable_funcs'}, $dtable);

# Disabled classes
print &ui_table_row($text{'disable_classes'},
    &ui_textbox("disable_classes",  &find_value("disable_classes", $conf), 60));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("list_ini.cgi?file=".&urlize($in{'file'}),
		 $text{'list_return'});
