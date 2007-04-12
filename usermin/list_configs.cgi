#!/usr/local/bin/perl
# lists_configs.cgi
# List all usermin modules that can be configured

require './usermin-lib.pl';
$access{'configs'} || &error($text{'acl_ecannot'});
&ReadParse();
&ui_print_header(undef, $text{'configs_title'}, "");

@mods = &list_modules();
&get_usermin_miniserv_config(\%miniserv);
print "$text{'configs_desc'}<p>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'configs_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
foreach $m (@mods) {
	if ((-r "$miniserv{'root'}/$m->{'dir'}/config.info" ||
	    -r "$miniserv{'root'}/$m->{'dir'}/uconfig.info") &&
	    &can_use_module($m->{'dir'})) {
		print "<tr>\n" if ($i%3 == 0);
		print "<td><a href='edit_configs.cgi?mod=$m->{'dir'}'>",
		      "$m->{'desc'}</a></td>\n";
		print "</tr>\n" if ($i++%3 == 2);
		}
	}
print "</table></td></tr></table>\n";

&ui_print_footer("", $text{'index_return'});
