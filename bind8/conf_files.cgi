#!/usr/local/bin/perl
# conf_files.cgi
# Display global files options

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'files_ecannot'});
&ui_print_header(undef, $text{'files_title'}, "");

&ReadParse();
$conf = &get_config();
$options = &find("options", $conf);
$mems = $options->{'members'};

print "<form action=save_files.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'files_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
print &opt_input($text{'files_stats'}, "statistics-file", $mems,
		 $text{'default'}, 40, &file_chooser_button("statistics_file"));
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'files_dump'}, "dump-file", $mems,
		 $text{'default'}, 40, &file_chooser_button("dump_file"));
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'files_pid'}, "pid-file", $mems,
		 $text{'default'}, 40, &file_chooser_button("pid_file"));
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'files_xfer'}, "named-xfer", $mems,
		 $text{'default'}, 40, &file_chooser_button("named_xfer"));
print "</tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});


