#!/usr/local/bin/perl
# save_dir.cgi
# Save some kind of per-directory configuration

require './apache-lib.pl';
&ReadParse();
($vconf, $v) = &get_virtual_config($in{'virt'});
&can_edit_virt($v) || &error($text{'virt_ecannot'});
$access_types{$in{'type'}} || &error($text{'etype'});
$d = $vconf->[$in{'idx'}];
$conf = $d->{'members'};
@edit = &editable_directives($in{'type'}, 'directory');

&error_setup(&text('efailed', $text{"type_$in{'type'}"}));
&parse_inputs(\@edit, $conf, &get_config());
&webmin_log("dir", $in{'type'},
	    &virtual_name($v, 1).":".$d->{'words'}->[0], \%in);

&redirect("dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}");
