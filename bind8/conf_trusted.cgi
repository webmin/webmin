#!/usr/local/bin/perl
# Show a form for setting up DNSSEC verification and trusted keys
use strict;
use warnings;
# Globals
our (%access, %text);
our $dnssec_dlv_zone;

require './bind8-lib.pl';
&ReadParse();
$access{'defaults'} || &error($text{'trusted_ecannot'});
&supports_dnssec_client() || &error($text{'trusted_esupport'});
&ui_print_header(undef, $text{'trusted_title'}, "",
		 undef, undef, undef, undef, &restart_links());
my $conf = &get_config();
my $options = &find("options", $conf);
my $mems = $options->{'members'};
my @dlv = &find("dnssec-lookaside", $mems);
my $tkeys = &find("trusted-keys", $conf);
$tkeys ||= { 'members' => [ ] };

print &ui_form_start("save_trusted.cgi", "post");
print &ui_table_start($text{'trusted_header'}, undef, 2);

# DNSSEC enabled?
print &choice_input($text{'trusted_dnssec'}, 'dnssec-enable', $mems,
		    $text{'yes'}, 'yes', $text{'no'}, 'no',
		    $text{'default'}, undef);
if (&supports_dnssec_client() == 2) {
	print &choice_input($text{'trusted_validation'},
			    'dnssec-validation', $mems,
			    $text{'trusted_auto'}, 'auto',
			    $text{'yes'}, 'yes', $text{'no'}, 'no',
			    $text{'default'}, undef);
	}

# Trusted DLVs (obsolete)
if (@dlv) {
	my @dtable = ( );
	my $i = 0;
	foreach my $d (@dlv, { 'values' => [ '.' ] }) {
		my $dlv = $d->{'values'}->[0];
		$dlv = "" if ($dlv eq ".");
		push(@dtable, [
			&ui_opt_textbox("anchor_$i", $d->{'values'}->[2],
					30, $text{'trusted_none'}),
			&ui_opt_textbox("dlv_$i", $dlv, 20,
					$text{'trusted_root'}) ]);
		$i++;
		}
	print &ui_table_row($text{'trusted_dlvs'},
		&ui_radio("dlv_auto",
		  @dlv == 0 ? 2 :
		  @dlv == 1 && $dlv[0]->{'values'}->[0] eq 'auto' ? 1 : 0,
		  [ [ 1, $text{'trusted_dlvs1'} ],
		    [ 2, $text{'trusted_dlvs2'} ],
		    [ 0, $text{'trusted_dlvs0'} ] ])."<br>\n".
		&ui_columns_table([ $text{'trusted_anchor'},
				    $text{'trusted_dlv'} ],
				  undef,
				  \@dtable), 3);
	}

# Trusted keys
if (@{$tkeys->{'members'}}) {
	my @ktable = ( );
	my $i = 0;
	foreach my $k (@{$tkeys->{'members'}}, { 'values' => [ ] }) {
		my @v = @{$k->{'values'}};
		my @wrapped = ( );
		while(length($v[3]) > 30) {
			push(@wrapped, substr($v[3], 0, 30));
			$v[3] = substr($v[3], 30);
			}
		push(@wrapped, $v[3]);
		push(@ktable, [
			&ui_opt_textbox("zone_$i", $k->{'name'}, 20,
					$text{'trusted_none'}),
			&ui_textbox("flags_$i", $v[0], 6),
			&ui_textbox("proto_$i", $v[1], 6),
			&ui_textbox("alg_$i", $v[2], 6),
			&ui_textarea("key_$i", join("\n", @wrapped), 4, 32) ]);
		$i++;
		}
	print &ui_table_row($text{'trusted_keys'},
		&ui_columns_table([
			$text{'trusted_zone'}, $text{'trusted_flags'},
			$text{'trusted_proto'}, $text{'trusted_alg'},
			$text{'trusted_key'} ],
			undef, \@ktable), 3);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
