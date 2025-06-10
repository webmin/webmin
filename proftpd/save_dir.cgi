#!/usr/local/bin/perl
# save_virt.cgi
# Save some kind of per-directory configuration

require './proftpd-lib.pl';
&ReadParse();
if ($in{'global'}) {
	$conf = &get_config();
	$vconf = &get_or_create_global($conf);
	}
else {
	($vconf, $v) = &get_virtual_config($in{'virt'});
	}
if ($in{'anon'}) {
	$anon = &find_directive_struct("Anonymous", $vconf);
	$vconf = $anon->{'members'};
	}
$d = $vconf->[$in{'idx'}];
$conf = $d->{'members'};
@edit = &editable_directives($in{'type'}, 'directory');

&lock_file($d->{'file'});
$tn = $type_name[$in{'type'}]; $tn =~ tr/A-Z/a-z/;
&error_setup(&text('efailed', $text{"type_$in{'type'}"}));
&parse_inputs(\@edit, $conf, &get_config());
&unlock_file($d->{'file'});
&webmin_log("dir", $in{'type'},
	    "$v->{'value'}:$d->{'words'}->[0]", \%in);

&redirect("dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}&anon=$in{'anon'}&global=$in{'global'}");
