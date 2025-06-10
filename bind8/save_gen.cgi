#!/usr/local/bin/perl
# save_gen.cgi
# Save $generate records

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in);
# From records-lib.pl
our ($uscore, $star);

require './bind8-lib.pl';
&ReadParse();
$access{'gen'} || &error($text{'gen_ecannot'});

my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $dom = $zone->{'name'};
&can_edit_zone($zone) || &error($text{'master_ecannot'});

my $file = $zone->{'file'};
if (!$in{'show'}) {
	&lock_file(&make_chroot(&absolute_path($zone->{'file'})));
	&before_editing($zone);
	}
my @recs = &read_zone_file($file, $dom);
my @gens = grep { $_->{'generate'} } @recs;

if ($in{'show'}) {
	# Just show what would be generated
	my $desc = &text('recs_header', &ip6int_to_net(&arpa_to_ip($dom)));
	&ui_print_header($desc, $text{'gen_title2'}, "",
			 undef, undef, undef, undef, &restart_links($zone));

	print &ui_columns_start([ $text{'recs_name'}, $text{'recs_type'},
				  $text{'recs_ttl'}, $text{'recs_vals'},
				  $text{'gen_raw'} ], 100);
	foreach my $g (@gens) {
		my @gv = @{$g->{'generate'}};
		my ($start, $end, $skip);
		if ($gv[0] =~ /^(\d+)-(\d+)\/(\d+)$/) {
			$start = $1; $end = $2; $skip = $3;
			}
		elsif ($gv[0] =~ /^(\d+)-(\d+)$/) {
			$start = $1; $end = $2; $skip = 1;
			}
		else { next; }
		for(my $i=$start; $i<=$end; $i+=$skip) {
			my $lhs = $gv[1];
			$lhs =~ s/\$\$/\0/g;
			$lhs =~ s/\$/$i/g;
			$lhs =~ s/\0/\$/g;
			my $lhsfull = $lhs =~ /\.$/ ? $lhs :
				    $dom eq "." ? "$lhs." : "$lhs.$dom";

			my $rhs = $gv[3];
			$rhs =~ s/\$\$/\0/g;
			#$rhs =~ s/\$/$i/g;
			$rhs =~ s/(\$(\{[^\}]*\})?)/&expand_mods($i,$2)/ge;
			$rhs =~ s/\0/\$/g;
			my $rhsfull = &check_ipaddress($rhs) ? $rhs :
				   $rhs =~ /\.$/ ? $rhs :
				    $dom eq "." ? "$rhs." : "$rhs.$dom";

			print &ui_columns_row([
				&arpa_to_ip($lhsfull), $gv[2],
				$text{'default'}, &arpa_to_ip($rhsfull),
				"<tt>$lhs IN $gv[2] $rhs</tt>" ]);
			}
		}
	print &ui_columns_end();

	&ui_print_footer("edit_master.cgi?zone=$in{'zone'}&view=$in{'view'}",
		$text{'master_return'});
	exit;
	}

# Parse and validate inputs
&error_setup($text{'gen_err'});
for(my $i=0; defined($in{"type_$i"}); $i++) {
	if ($in{"type_$i"}) {
		my @gv;
		$in{"start_$i"} =~ /^\d+$/ ||
			&error(&text('gen_estart', $i+1));
		$in{"stop_$i"} =~ /^\d+$/ ||
			&error(&text('gen_estop', $i+1));
		$in{"start_$i"} <= $in{"stop_$i"} ||
			&error(&text('gen_erange', $i+1));
		$in{"skip_$i"} =~ /^\d*$/ ||
			&error(&text('gen_eskip', $i+1));
		push(@gv, $in{"start_$i"}."-".$in{"stop_$i"});
		if ($in{"skip_$i"}) {
			$gv[$#gv] .= "/".$in{"skip_$i"};
			}
		$in{"name_$i"} =~ /^[A-Za-z0-9\.\-$uscore$star\$\{\},]+$/ ||
			&error(&text('gen_ename', $i+1));
		push(@gv, $in{"name_$i"});
		push(@gv, $in{"type_$i"});
		$in{"value_$i"} =~ /^[A-Za-z0-9\.\-$uscore$star\$\{\},]+$/ ||
			&error(&text('gen_evalue', $i+1));
		push(@gv, $in{"value_$i"});
		push(@gv, $in{"cmt_$i"}) if ($in{"cmt_$i"});
		if ($i < @gens) {
			&modify_generator($gens[$i]->{'file'}, $gens[$i], @gv);
			}
		else {
			&create_generator($file, @gv);
			}
		}
	else {
		if ($i < @gens) {
			&delete_generator($gens[$i]->{'file'}, $gens[$i]);
			foreach my $g (@gens) {
				if ($g->{'line'} > $gens[$i]->{'line'}) {
					$g->{'line'}--;
					}
				}
			}
		}
	}
&bump_soa_record($file, \@recs);
&sign_dnssec_zone_if_key($zone, \@recs);
&after_editing($zone);
&unlock_file(&make_chroot(&absolute_path($zone->{'file'})));
&redirect("edit_master.cgi?zone=$in{'zone'}&view=$in{'view'}");

sub expand_mods
{
my ($i, $m) = @_;
$m =~ s/^\{//;
$m =~ s/\}$//;
my ($o, $w, $b) = split(/,/, $m);
if ($o !~ /^\-?\d+$/) {
	# Disallowed offset
	$o = 0;
	}
if ($w !~ /^\d+$/) {
	# Disallowed width
	$w = 0;
	}
if ($b !~ /^[doxXnN]$/) {
	# Disallowed modifier
	$b = undef;
	}
$b ||= "d";
$i += $o;
$i = sprintf("%".($w ? "0".$w : "").$b, $i);
return $i;
}
