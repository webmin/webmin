#!/usr/local/bin/perl
# save_global.cgi
# Save some type of global options

require './proftpd-lib.pl';
&ReadParse();
&lock_proftpd_files();
$conf = &get_config();
$gconf = &get_or_create_global($conf);
@edit = &editable_directives($in{'type'}, 'root');
@gedit = &editable_directives($in{'type'}, 'global');

&error_setup(&text('efailed', $text{"type_$in{'type'}"}));
&parse_inputs(\@edit, $conf, $conf);
&parse_inputs(\@gedit, $gconf, $conf);
&unlock_proftpd_files();
&webmin_log("global", $in{'type'}, undef, \%in);

&redirect("");

