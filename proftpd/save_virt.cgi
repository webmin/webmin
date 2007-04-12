#!/usr/local/bin/perl
# save_virt.cgi
# Save some kind of per-server configuration

require './proftpd-lib.pl';
&ReadParse();
($conf, $v) = &get_virtual_config($in{'virt'});
@edit = &editable_directives($in{'type'}, 'virtual');

&lock_proftpd_files();
&error_setup(&text('efailed', $text{"type_$in{'type'}"}));
&parse_inputs(\@edit, $conf, &get_config());
&unlock_proftpd_files();
&webmin_log("virt", $in{'type'}, $in{'virt'} ? $v->{'value'} : "", \%in);

&redirect("virt_index.cgi?virt=$in{'virt'}");
