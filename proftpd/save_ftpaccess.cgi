#!/usr/local/bin/perl
# save_ftpaccess.cgi
# Save some kind of per-directory options file

require './proftpd-lib.pl';
&ReadParse();
$conf = &get_ftpaccess_config($in{'file'});
@edit = &editable_directives($in{'type'}, 'ftpaccess');

&lock_file($in{'file'});
&error_setup(&text('efailed', $text{"type_$in{'type'}"}));
&parse_inputs(\@edit, $conf, $conf);
&unlock_file($in{'file'});
&webmin_log("ftpaccess", $in{'type'}, $in{'file'}, \%in);

&redirect("ftpaccess_index.cgi?file=$in{'file'}");
