#!/usr/local/bin/perl
# Show form for manually editing php.ini

require './phpini-lib.pl';
&ReadParse();
&error_setup($text{'manual_err'});
&can_php_config($in{'file'}) || &error($text{'manual_ecannot'});
$access{'manual'} || &error($text{'manual_ecannot'});

&ui_print_header("<tt>$in{'file'}</tt>", $text{'manual_title'}, "");

print $text{'manual_desc'},"<p>\n";
print &ui_form_start("save_manual.cgi", "form-data");
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_hidden("oneini", $in{'oneini'}),"\n";
print &ui_textarea("data", &read_file_contents_as_user($in{'file'}), 20, 80);
print &ui_form_end([ [ "save", $text{'save'} ] ]);

if ($in{'oneini'}) {
        &ui_print_footer("list_ini.cgi?file=".&urlize($in{'file'}),
                         $text{'list_return'});
        }
else {
        &ui_print_footer("", $text{'index_return'});
        }

