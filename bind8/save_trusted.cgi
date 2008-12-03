#!/usr/local/bin/perl
# Save DNSSEC verification options

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'trusted_ecannot'});
&error_setup($text{'trusted_err'});
&ReadParse();

&lock_file(&make_chroot($config{'named_conf'}));
$conf = &get_config();
$options = &find("options", $conf);

# DNSSEC enabled
&save_choice("dnssec-enable", $options, 1);

# Save DLV zones
@dlvs = ( );
for($i=0; defined($in{"anchor_$i"}); $i++) {
	if (!$in{"anchor_${i}_def"}) {
		$in{"anchor_$i"} =~ /^[a-z0-9\.\-\_]+$/ ||
			&error(&text('trusted_eanchor', $i+1));
		$in{"anchor_$i"} .= "." if ($in{"anchor_$i"} !~ /\.$/);
		if ($in{"dlv_${i}_def"}) {
			$dlv = ".";
			}
		else {
			$in{"dlv_$i"} =~ /^[a-z0-9\.\-\_]+$/ ||
				&error(&text('trusted_edlv', $i+1));
			$dlv = $in{"dlv_$i"};
			$dlv .= "." if ($dlv !~ /\.$/);
			}
		push(@dlvs, { 'name' => 'dnssec-lookaside',
			      'values' => [ $dlv, "trust-anchor",
					    $in{"anchor_$i"} ] });
		}
	}
&save_directive($options, "dnssec-lookaside", \@dlvs, 1);

# Save trusted keys
# XXX

&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&webmin_log("trusted");
&redirect("");

