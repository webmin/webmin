#!/usr/local/bin/perl
# index.cgi

require './krb5-lib.pl';

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		 &help_search_link("krb5", "man"));

if (!-r $config{'krb5_conf'}) {
	&ui_print_endpage(
		&ui_config_link('index_econf',
			[ "<tt>$config{'krb5_conf'}</tt>", undef ]));
	}

%conf = &get_config();

print "<form action=\"save.cgi\">\n";
print "<table border width=100%>\n";
print "<tr $cb> <td><table width=100%>\n";
print "<tr $tb> <td colspan=4><b>$text{'logging'}</b></td> </tr>\n";

print "<tr $cb> <td>",&hlink("<b>$text{'default_log'}</b>","default_log"),"</td>\n";
print "<td><input name=default_log size=40 value=\"$conf{'default_log'}\">",
    &file_chooser_button("default_log", 1), "</td></tr>\n";

print "<tr $cb> <td>",&hlink("<b>$text{'kdc_log'}</b>","kdc_log"),"</td>\n";
print "<td><input name=kdc_log size=40 value=\"$conf{'kdc_log'}\">",
    &file_chooser_button("kdc_log", 1), "</td></tr>\n";

print "<tr $cb> <td>",&hlink("<b>$text{'admin_log'}</b>","admin_log"),"</td>\n";
print "<td><input name=admin_log size=40 value=\"$conf{'admin_server_log'}\">",
    &file_chooser_button("admin_log", 1), "</td></tr>\n";

print "<tr $tb> <td colspan=3><b>$text{'libdefaults'}</b></td> </tr>\n";

print "<tr> <td>",&hlink("<b>$text{'default_realm'}</b>","default_realm"),"</td>\n";
print "<td><input name=default_realm size=40 value=\"$conf{'realm'}\"> </td></tr>\n";

print "<tr> <td>",&hlink("<b>$text{'domain'}</b>","domain"),"</td>\n";
print "<td><input name=domain size=40 value=\"$conf{'domain'}\"> </td></tr>\n";

print "<tr> <td>",&hlink("<b>$text{'default_domain'}</b>","default_domain"),"</td>\n";
print "<td><input name=default_domain size=40 value=\"$conf{'default_domain'}\"> </td></tr>\n";

print "<tr> <td>",&hlink("<b>$text{'dns_kdc'}</b>","dns_kdc"),"</td>\n";
printf "<td><input type=radio name=dns_kdc value=1 %s> $text{'yes'}\n",
    ($conf{'dns_lookup_kdc'} eq "false") ? "" : "checked";
printf "<input type=radio name=dns_kdc value=0 %s> $text{'no'}</td></tr>\n",
    ($conf{'dns_lookup_kdc'} eq "false") ? "checked" : "";

print "<tr> <td>",&hlink("<b>$text{'default_kdc'}</b>","default_kdc"),"</td>\n";
print "<td><input name=default_kdc size=40 value=\"$conf{'kdc'}\"> : ";
print "<input name=default_kdc_port size=5 value=\"$conf{'kdc_port'}\"> </td></tr>\n";

print "<tr> <td>",&hlink("<b>$text{'default_admin'}</b>","default_admin"),"</td>\n";
print "<td><input name=default_admin size=40 value=\"$conf{'admin_server'}\"> : ";
print "<input name=default_admin_port size=5 value=\"$conf{'admin_port'}\"> </td></tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("/", $text{'index'});
