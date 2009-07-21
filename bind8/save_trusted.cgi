#!/usr/local/bin/perl
# Save DNSSEC verification options

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'trusted_ecannot'});
&error_setup($text{'trusted_err'});
&ReadParse();

&lock_file(&make_chroot($config{'named_conf'}));
$parent = &get_config_parent();
$conf = $parent->{'members'};
$options = &find("options", $conf);

# DNSSEC enabled
&save_choice("dnssec-enable", $options, 1);
if (&supports_dnssec_client() == 2) {
	&save_choice("dnssec-validation", $options, 1);
	}

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
@keys = ( );
$trusted = &find("trusted-keys", $conf);
if (!$trusted) {
	# Need to create block
	$trusted = { 'name' => 'trusted-keys',
		     'type' => 1,
		     'members' => [ ] };
	&save_directive($parent, "trusted-keys", [ $trusted ]);
	}
for($i=0; defined($in{"zone_$i"}); $i++) {
	next if ($in{"zone_${i}_def"});
	$in{"zone_$i"} =~ /^[a-z0-9\.\-\_]+$/ ||
		&error(&text('trusted_ezone', $i+1));
	$in{"zone_$i"} .= "." if ($in{"zone_$i"} !~ /\.$/);
	$in{"flags_$i"} =~ /^\d+$/ ||
		&error(&text('trusted_eflags', $i+1));
	$in{"proto_$i"} =~ /^\d+$/ ||
		&error(&text('trusted_eproto', $i+1));
	$in{"alg_$i"} =~ /^\d+$/ ||
		&error(&text('trusted_ealg', $i+1));
	$in{"key_$i"} =~ s/\s//g;
	$in{"key_$i"} || &error(&text('trusted_ekey', $i+1));
	push(@keys, { 'name' => $in{"zone_$i"},
		      'values' => [ $in{"flags_$i"}, $in{"proto_$i"},
				    $in{"alg_$i"}, '"'.$in{"key_$i"}.'"' ],
		    });
	}
@oldkeys = @{$trusted->{'members'}};
&save_directive($trusted, \@oldkeys, \@keys, 1);

&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&webmin_log("trusted");
&redirect("");

