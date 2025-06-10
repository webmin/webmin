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

print &ui_form_start("save.cgi", "post");
print &ui_table_start($text{'logging'}, undef, 2);
print &ui_table_row(&hlink("<b>$text{'default_log'}</b>","default_log"),
                    &ui_filebox("default_log", $conf{'default_log'}, 40));
print &ui_table_row(&hlink("<b>$text{'kdc_log'}</b>","kdc_log"),
                    &ui_filebox("kdc_log", $conf{'kdc_log'}, 40));
print &ui_table_row(&hlink("<b>$text{'admin_log'}</b>","admin_log"),
                    &ui_filebox("admin_log", $conf{'admin_server_log'}, 40));
print &ui_columns_header([$text{'libdefaults'},""]);

print &ui_table_row(&hlink("<b>$text{'default_realm'}</b>","default_realm"),
                    &ui_textbox("default_realm", $conf{'realm'}, 40));
print &ui_table_row(&hlink("<b>$text{'domain'}</b>","domain"),
                    &ui_textbox("domain", $conf{'domain'}, 40));
print &ui_table_row(&hlink("<b>$text{'default_domain'}</b>","default_domain"),
                    &ui_textbox("default_domain", $conf{'default_domain'}, 40));
print &ui_table_row(&hlink("<b>$text{'dns_kdc'}</b>","dns_kdc"),
                    &ui_oneradio("dns_kdc","1", $text{'yes'}, ( $conf{'dns_lookup_kdc'} eq "false" ? 0 : 1) )."&nbsp;".
                    &ui_oneradio("dns_kdc","0", $text{'no'}, ( $conf{'dns_lookup_kdc'} eq "false" ? 1 : 0) ) );
print &ui_table_row(&hlink("<b>$text{'default_kdc'}</b>","default_kdc"),
                    &ui_textbox("default_kdc", $conf{'kdc'}, 40).":".&ui_textbox("kdc", $conf{'kdc_port'}, 5));
print &ui_table_row(&hlink("<b>$text{'default_admin'}</b>","default_admin"),
                    &ui_textbox("default_admin", $conf{'admin_server'}, 40).":".&ui_textbox("default_admin_port", $conf{'admin_port'}, 5));
print ui_table_end();
print "<br>";
print &ui_submit($text{'save'});
print &ui_form_end();

&ui_print_footer("/", $text{'index'});
