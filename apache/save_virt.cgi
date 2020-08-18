#!/usr/local/bin/perl
# save_virt.cgi
# Save some kind of per-server configuration

require './apache-lib.pl';
&ReadParse();
($conf, $v) = &get_virtual_config($in{'virt'});
&can_edit_virt($v) || &error($text{'virt_ecannot'});
$access_types{$in{'type'}} || &error($text{'etype'});
if ($in{'type'} == 14) {
	$in{'SSLProtocol'} || &error($text{'virt_eprotocol'});
	}
$in{'type'} == 8 && !$access{'vuser'} &&
	&error($text{'virt_euser'});
@edit = &editable_directives($in{'type'}, 'virtual');
if (!$in{'virt'}) {
	@edit = grep { !$_->{'virtualonly'} } @edit;
	}
if ($in{'type'} == 5 && &is_virtualmin_domain($v)) {
	@edit = grep { $_->{'name'} ne 'DocumentRoot' &&
		       $_->{'name'} ne 'ServerPath' } @edit;
	}
elsif ($in{'type'} == 1 && &is_virtualmin_domain($v)) {
	@edit = grep { $_->{'name'} ne 'ServerName' &&
		       $_->{'name'} ne 'ServerAlias' } @edit;
	}

&error_setup(&text('efailed', $text{"type_$in{'type'}"}));
&parse_inputs(\@edit, $conf, &get_config());
&webmin_log("virt", $in{'type'}, &virtual_name($v, 1), \%in);

&redirect("virt_index.cgi?virt=$in{'virt'}");
