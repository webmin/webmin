#!/usr/local/bin/perl
# Show options related to error reporting and logging

require './phpini-lib.pl';
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$conf = &get_config($in{'file'});

&ui_print_header("<tt>$in{'file'}</tt>", $text{'errors_title'}, "");

print &ui_form_start("save_errors.cgi", "post");
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_table_start($text{'errors_header'}, "width=100%", 4);

# Show and log errors
print &ui_table_row($text{'errors_display'},
		    &onoff_radio("display_errors"));
print &ui_table_row($text{'errors_log'},
		    &onoff_radio("log_errors"));

# Ignore repeated
print &ui_table_row($text{'errors_ignore'},
		    &onoff_radio("ignore_repeated_errors"));
print &ui_table_row($text{'errors_source'},
		    &onoff_radio("ignore_repeated_source"));

# Error types to show
$errs = &find_value("error_reporting", $conf);
if ($errs =~ /^[A-Z_\|]*$/) {
	# An | of error bits
	@errs = split(/\|/, $errs);
	$i = 0;
	$etable = "<table>\n";
	foreach $et ("E_ALL", "E_ERROR", "E_WARNING", "E_PARSE", "E_NOTICE",
		     "E_CORE_ERROR", "E_CORE_WARNING", "E_COMPILE_ERROR",
		     "E_COMPILE_WARNING", "E_USER_ERROR", "E_USER_WARNING",
		     "E_USER_NOTICE") {
		$etable .= "<tr>\n" if ($i%4 == 0);
		$etable .= "<td>".
		    &ui_checkbox("error_bits", $et,
			$text{'errors_'.$et}, &indexof($et, @errs) >= 0).
		    "</td>\n";
		$etable .= "</tr>\n" if ($i++%4 == 3);
		}
	$etable .= "</table>\n";
	print &ui_table_row($text{'errors_bits'}, $etable, 3);
	}
else {
	# Custom expression
	print &ui_table_row($text{'errors_reporting'},
	    &ui_opt_textbox("error_reporting", $errs, 60, $text{'default'}), 3);
	}

# Max error length
$ml = &find_value("log_errors_max_len", $conf);
print &ui_table_row($text{'errors_maxlen'},
		    &ui_opt_textbox("log_errors_max_len", $ml || undef, 5,
				    $text{'errors_unlimited'}));

# Where to log errors
$el = &find_value("error_log", $conf);
print &ui_table_row($text{'errors_file'},
	&ui_radio("error_log_def", $el eq "syslog" ? 1 : $el ? 2 : 0,
		  [ [ 0, $text{'errors_none'} ],
		    [ 1, $text{'errors_syslog'} ],
		    [ 2, &text('errors_other',
		       &ui_textbox("error_log", $el eq "syslog" ? "" : $el, 40))
		    ] ]), 3);

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("list_ini.cgi?file=".&urlize($in{'file'}),
		 $text{'list_return'});
