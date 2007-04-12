#!/usr/local/bin/perl
# save_virt.cgi
# Save some kind of per-server configuration

require './apache-lib.pl';
&ReadParse();
($conf, $v) = &get_virtual_config($in{'virt'});
&can_edit_virt($v) || &error($text{'virt_ecannot'});
$access_types{$in{'type'}} || &error($text{'etype'});
$in{'type'} == 8 && !$access{'vuser'} &&
	&error($text{'virt_euser'});
@edit = &editable_directives($in{'type'}, 'virtual');
if (!$in{'virt'}) {
	@edit = grep { !$_->{'virtualonly'} } @edit;
	}

&error_setup(&text('efailed', $text{"type_$in{'type'}"}));
&parse_inputs(\@edit, $conf, &get_config());
&webmin_log("virt", $in{'type'}, &virtual_name($v, 1), \%in);

&redirect("virt_index.cgi?virt=$in{'virt'}");
