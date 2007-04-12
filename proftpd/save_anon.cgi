#!/usr/local/bin/perl
# save_anon.cgi
# Save some kind of anonymous section configuration

require './proftpd-lib.pl';
&ReadParse();
($vconf, $v) = &get_virtual_config($in{'virt'});
$anon = &find_directive_struct("Anonymous", $vconf);
$conf = $anon->{'members'};
@edit = &editable_directives($in{'type'}, 'anon');

&lock_file($anon->{'file'});
&error_setup(&text('efailed', $text{"type_$in{'type'}"}));
&parse_inputs(\@edit, $conf, &get_config());
&unlock_file($anon->{'file'});
&webmin_log("anon", $in{'type'}, $in{'virt'} ? $v->{'value'} : "", \%in);

&redirect("anon_index.cgi?virt=$in{'virt'}");
