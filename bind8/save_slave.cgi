#!/usr/local/bin/perl
# save_slave.cgi
# Save changes to slave zone options in named.conf

require './bind8-lib.pl';
&ReadParse();
$conf = &get_config();
if ($in{'view'} ne '') {
	$view = $conf->[$in{'view'}];
	$conf = $view->{'members'};
	$indent = 2;
	}
else {
	$indent = 1;
	}
$zconf = $conf->[$in{'index'}];
&lock_file(&make_chroot($zconf->{'file'}));
&error_setup($text{'slave_err'});
&can_edit_zone($zconf, $view) ||
	&error($text{'slave_ecannot'});
$access{'ro'} && &error($text{'master_ero'});
$access{'opts'} || &error($text{'master_eoptscannot'});

&save_port_address("masters", "port", $zconf, $indent);
&save_opt("max-transfer-time-in", \&mtti_check, $zconf, $indent);
&save_opt("file", \&file_check, $zconf, $indent);
&save_choice("check-names", $zconf, $indent);
&save_choice("notify", $zconf, $indent);
&save_addr_match("allow-update", $zconf, $indent);
&save_addr_match("allow-transfer", $zconf, $indent);
&save_addr_match("allow-query", $zconf, $indent);
&save_address("also-notify", $zconf, $indent);
&flush_file_lines();
&unlock_file(&make_chroot($zconf->{'file'}));
&webmin_log("opts", undef, $zconf->{'value'}, \%in);
&redirect("edit_slave.cgi?index=$in{'index'}&view=$in{'view'}");

sub mtti_check
{
return $_[0] =~ /^\d+$/ ? undef : &text('slave_emax', $_[0]);
}

sub file_check
{
return $text{'slave_efile'} if ($_[0] !~ /\S/);
local $file = $_[0];
if ($_[0] !~ /^\//) {
	$file = &base_directory($conf)."/".$file;
	}
return &allowed_zone_file(\%access, $file) ? undef :
	&text('slave_efile2', $_[0]);
}

