#!/usr/local/bin/perl
# change_theme.cgi
# Change the current webmin theme

require './webmin-lib.pl';
&ReadParse();

&lock_file("$config_directory/config");
$gconfig{'theme'} = $in{'theme'};
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
if ($in{'theme'}) {
	$miniserv{'preroot'} = $in{'theme'};
	}
else {
	delete($miniserv{'preroot'});
	}
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});
&reload_miniserv();

&webmin_log('theme', undef, undef, \%in);
&ui_print_header(undef, $text{'themes_title'}, "");
print "<script>\n";
print "top.location = \"/\";\n";
print "</script>\n";
print "<p>$text{'themes_ok'}<p>\n";
&ui_print_footer("", $text{'index_return'});

