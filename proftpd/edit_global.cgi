#!/usr/local/bin/perl
# edit_global.cgi
# Display a form for editing some kind of global options

require './proftpd-lib.pl';
&ReadParse();
$conf = &get_config();
$global = &find_directive_struct("Global", $conf);
if ($global) {
	$gconf = $global->{'members'};
	}
&ui_print_header(undef, $text{"type_$in{'type'}"}, "",
	undef, undef, undef, undef, &restart_button());

print &ui_form_start("save_global.cgi", "post");
print &ui_hidden("type", $in{'type'});
print &ui_table_start($text{"type_$in{'type'}"}, "width=100%", 4);

@dirs = &editable_directives($in{'type'}, 'root');
&generate_inputs(\@dirs, $conf);
@gdirs = &editable_directives($in{'type'}, 'global');
if (@dirs && @gdirs) {
	print &ui_table_hr();
	}
&generate_inputs(\@gdirs, $gconf);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


