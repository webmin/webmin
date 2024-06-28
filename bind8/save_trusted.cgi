#!/usr/local/bin/perl
# Save DNSSEC verification options
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in, %config, $bind_version);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'trusted_ecannot'});
&error_setup($text{'trusted_err'});
&ReadParse();

&lock_file(&make_chroot($config{'named_conf'}));
my $parent = &get_config_parent();
my $conf = $parent->{'members'};
my $options = &find("options", $conf);

# DNSSEC enabled
if (&compare_version_numbers($bind_version, '<', '9.16.0')) {
	&save_choice("dnssec-enable", $options, 1);
	}
if (&supports_dnssec_client() == 2) {
	&save_choice("dnssec-validation", $options, 1);
	}

# Save trusted keys
if (defined($in{'zone_0'})) {
	my @keys = ( );
	my $trusted = &find("trusted-keys", $conf);
	for(my $i=0; defined($in{"zone_$i"}); $i++) {
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
					    $in{"alg_$i"},
					    '"'.$in{"key_$i"}.'"' ],
			    });
		}
	if (!$trusted && @keys) {
		# Need to create block
		$trusted = { 'name' => 'trusted-keys',
			     'type' => 1,
			     'members' => [ ] };
		&save_directive($parent, "trusted-keys", [ $trusted ]);
		}
	my @oldkeys = @{$trusted->{'members'}};
	&save_directive($trusted, \@oldkeys, \@keys, 1);
	}

&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&webmin_log("trusted");
&redirect("");

