#!/usr/local/bin/perl
# save_global.cgi
# Save some type of global options

require './apache-lib.pl';
&ReadParse();
$access{'global'}==1 || &error($text{'global_ecannot'});
$access_types{$in{'type'}} ||
	&error($text{'etype'});
$conf = &get_config();
@edit = &editable_directives($in{'type'}, 'global');

&error_setup(&text('efailed', $text{"type_$in{'type'}"}));
&parse_inputs(\@edit, $conf, $conf);
&webmin_log("global", $in{'type'}, undef, \%in);

&redirect("index.cgi?mode=global");

