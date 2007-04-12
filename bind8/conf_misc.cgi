#!/usr/local/bin/perl
# conf_misc.cgi
# Display miscellaneous options

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'misc_ecannot'});
&ui_print_header(undef, $text{'misc_title'}, "");

&ReadParse();
$conf = &get_config();
$options = &find("options", $conf);
$mems = $options->{'members'};

print "<form action=save_misc.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'misc_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
print &opt_input($text{'misc_core'}, 'coresize', $mems, $text{'default'}, 8);
print &opt_input($text{'misc_data'}, 'datasize', $mems, $text{'default'}, 8);
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'misc_files'}, 'files', $mems, $text{'default'}, 8);
print &opt_input($text{'misc_stack'}, 'stacksize', $mems, $text{'default'}, 8);
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr>\n";
print &opt_input($text{'misc_clean'}, 'cleaning-interval', $mems,
		 $text{'default'}, 8, "$text{'misc_mins'}");
print &opt_input($text{'misc_iface'}, 'interface-interval', $mems,
		 $text{'default'}, 8, "$text{'misc_mins'}");
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'misc_stats'}, 'statistics-interval', $mems,
		 $text{'default'}, 8, "$text{'misc_mins'}");
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr>\n";
print &choice_input($text{'misc_recursion'}, 'recursion', $mems,
		    $text{'yes'}, 'yes', $text{'no'}, 'no',
		    $text{'default'}, undef);
print &choice_input($text{'misc_cnames'}, 'multiple-cnames', $mems,
		    $text{'yes'}, 'yes', $text{'no'}, 'no',
		    $text{'default'}, undef);
print "</tr>\n";

print "<tr>\n";
print &choice_input($text{'misc_glue'}, 'fetch-glue', $mems,
		    $text{'yes'}, 'yes', $text{'no'}, 'no',
		    $text{'default'}, undef);
print &choice_input($text{'misc_nx'}, 'auth-nxdomain', $mems,
		    $text{'yes'}, 'yes', $text{'no'}, 'no',
		    $text{'default'}, undef);
print "</tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});


