#!/usr/local/bin/perl
# save_zonedef.cgi
# Save zone defaults
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in, %config);
our $module_config_directory;

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'zonedef_err'});
$access{'defaults'} || &error($text{'zonedef_ecannot'});

&lock_file(&make_chroot($config{'named_conf'}));
&lock_file("$module_config_directory/zonedef");
my $conf = &get_config();
my $options = &find("options", $conf);
my @check;
foreach my $c ("master", "slave", "response") {
	push(@check, { 'name' => 'check-names',
		       'values' => [ $c, $in{$c} ] }) if ($in{$c});
	}
&save_directive($options, 'check-names', \@check, 1);
&save_addr_match("allow-transfer", $options, 1);
&save_addr_match("allow-query", $options, 1);
&save_addr_match("also-notify", $options, 1);
&save_choice("notify", $options, 1);

$in{'refresh'} =~ /^\d+$/ || &error(&text('master_erefresh', $in{'refresh'}));
$in{'retry'} =~ /^\d+$/ || &error(&text('master_eretry', $in{'retry'}));
$in{'expiry'} =~ /^\d+$/ || &error(&text('master_eexpiry', $in{'expiry'}));
$in{'minimum'} =~ /^\d+$/ || &error(&text('master_eminimum', $in{'minimum'}));
my %zonedef = ( 'refresh', $in{'refresh'},
	     'retry', $in{'retry'},
	     'expiry', $in{'expiry'},
	     'minimum', $in{'minimum'},
	     'refunit', $in{'refunit'},
	     'retunit', $in{'retunit'},
	     'expunit', $in{'expunit'},
	     'minunit', $in{'minunit'} );

&lock_file("$module_config_directory/config");
foreach my $k (keys %config) {
	delete($config{$k}) if ($k =~ /^tmpl_/);
	}
my $j=0;
for(my $i=0; defined($in{"name_$i"}); $i++) {
	next if (!$in{"name_$i"});
	$in{"type_$i"} eq 'A' || !$in{"def_$i"} ||
		&error($text{'master_eiptmpl'});
	$config{"tmpl_$j"} = join(' ', $in{"name_$i"}, $in{"type_$i"},
			  $in{"value_${i}_def"} ? () : ( $in{"value_$i"} ) );
	$j++;
	}
$config{'tmpl_email'} = $in{'email'};
if ($in{'include_def'}) {
	delete($config{'tmpl_include'});
	}
else {
	-r $in{'include'} && !-d $in{'include'} ||
		&error($text{'master_einclude'});
	$config{'tmpl_include'} = $in{'include'};
	}
if ($in{'prins_def'}) {
	delete($config{'default_prins'});
	}
else {
	$in{'prins'} =~ /^[a-z0-9\.\-\_]+$/i ||
		&error($text{'zonedef_eprins'});
	$config{'default_prins'} = $in{'prins'};
	}
if (defined($in{'dnssec'})) {
	$config{'tmpl_dnssec'} = $in{'dnssec'};
	$config{'tmpl_dnssec_dt'} = $in{'dnssec_dt'};
	if ($config{'tmpl_dnssec_dt'}) {
		$config{'tmpl_dnssec_dne'} = $in{'dnssec_dne'};
	} else {
		$config{'tmpl_dnssecalg'} = $in{'alg'};
		my ($ok, $err) = &compute_dnssec_key_size($in{'alg'}, $in{'size_def'},
											   $in{'size'});
		&error($err) if (!$ok);
		$config{'tmpl_dnssecsizedef'} = $in{'size_def'};
		$config{'tmpl_dnssecsize'} = $in{'size'};
		$config{'tmpl_dnssecsingle'} = $in{'single'};
	}
}
&save_module_config();
&unlock_file("$module_config_directory/config");

&save_zone_defaults(\%zonedef);
&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&unlock_file("$module_config_directory/zonedef");
&webmin_log("zonedef", undef, undef, \%in);
&redirect("");

