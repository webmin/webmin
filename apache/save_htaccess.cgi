#!/usr/local/bin/perl
# save_htaccess.cgi
# Save some kind of per-directory options file

require './apache-lib.pl';
&ReadParse();
$access{'global'} || &error($text{'htaccess_ecannot'});
$access_types{$in{'type'}} ||
	&error($text{'etype'});
&allowed_auth_file($in{'file'}) ||
	&error($text{'htindex_ecannot'});
$conf = &get_htaccess_config($in{'file'});
@edit = &editable_directives($in{'type'}, 'htaccess');

&lock_file($in{'file'});
&error_setup(&text('efailed', $text{"type_$in{'type'}"}));
&parse_inputs(\@edit, $conf, $conf);
&unlock_file($in{'file'});
&webmin_log("htaccess", $in{'type'}, $in{'file'}, \%in);

&redirect("htaccess_index.cgi?file=".&urlize($in{'file'}));
