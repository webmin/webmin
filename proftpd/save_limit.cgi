#!/usr/local/bin/perl
# save_limit.cgi
# Save some kind of per-command configuration

require './proftpd-lib.pl';
&ReadParse();
if ($in{'file'}) {
	$conf = &get_ftpaccess_config($in{'file'});
	}
else {
	if ($in{'global'}) {
		$conf = &get_config();
		$conf = &get_or_create_global($conf);
		}
	else {
		($conf, $v) = &get_virtual_config($in{'virt'});
		}
	if ($in{'anon'}) {
		$anon = &find_directive_struct("Anonymous", $conf);
		$conf = $anon->{'members'};
		}
	if ($in{'idx'} ne '') {
		$conf = $conf->[$in{'idx'}]->{'members'};
		}
	}
$l = $conf->[$in{'limit'}];
$conf = $l->{'members'};
@edit = &editable_directives($in{'type'}, 'limit');

&lock_file($l->{'file'});
$tn = $type_name[$in{'type'}]; $tn =~ tr/A-Z/a-z/;
&error_setup(&text('efailed', $text{"type_$in{'type'}"}));
&parse_inputs(\@edit, $conf, &get_config());
&unlock_file($l->{'file'});
&webmin_log("limit", $in{'type'}, $l->{'value'}, \%in);

&redirect("limit_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}&limit=$in{'limit'}&anon=$in{'anon'}&global=$in{'global'}&file=$in{'file'}");
