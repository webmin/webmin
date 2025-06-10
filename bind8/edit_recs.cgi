#!/usr/local/bin/perl
# edit_recs.cgi
# Display records of some type from some domain
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in, %config, %is_extra);

require './bind8-lib.pl';
&ReadParse();
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'recs_ecannot'});
&can_edit_type($in{'type'}, \%access) ||
	&error($text{'recs_ecannottype'});
my $desc = &text('recs_header', &zone_subhead($zone));
my $typedesc = $text{"recs_$in{'type'}"} || $in{'type'};
&ui_print_header($desc, &text('recs_title', $typedesc), "",
		 undef, undef, undef, undef, &restart_links($zone));

# Show form for adding a record
my $type = $zone->{'type'};
$type = 'master' if ($type eq 'primary');
$type = 'slave' if ($type eq 'secondary');
my $file = $zone->{'file'};
my $form = 0;
my $shown_create_form;
my $newname = $in{'newname'} || ($in{'type'} eq 'DMARC' ? '_dmarc' : undef);
if (!$access{'ro'} && $type eq 'master' && $in{'type'} ne 'ALL') {
	&record_input($in{'zone'}, $in{'view'}, $in{'type'}, $file, $dom,
		      undef, undef, $newname, $in{'newvalue'});
	$form++;
	$shown_create_form = 1;
	}

my @allrecs;
my $nosearch;
if (!$config{'largezones'} || $in{'search'}) {
	# Get all records
	@allrecs = grep { !$_->{'generate'} && !$_->{'defttl'} }
		     &read_zone_file($file, $dom);
	$nosearch = 1 if (!@allrecs);
	}

if (!$nosearch) {
	# Show search form
	print &ui_form_start("edit_recs.cgi");
	print &ui_hidden("zone", $in{'zone'}),"\n";
	print &ui_hidden("view", $in{'view'}),"\n";
	print &ui_hidden("type", $in{'type'}),"\n";
	print "<b>$text{'recs_find'}</b>\n";
	print &ui_textbox("search", $in{'search'}, 20),"\n";
	print &ui_submit($text{'recs_search'}),"<p>\n";
	print &ui_form_end();
	$form++;
	}

my @recs;
if (!$config{'largezones'} || $in{'search'}) {
	# Get all records
	if ($in{'search'}) {
		# Limit to records matching some search
		foreach my $r (@allrecs) {
			if ($r->{'name'} =~ /\Q$in{'search'}\E/i) {
				push(@recs, $r);
				}
			else {
				foreach my $v (@{$r->{'values'}}) {
					if ($v =~ /\Q$in{'search'}\E/i) {
						push(@recs, $r);
						last;
						}
					}
				}
			}
		}
	else {
		# Show them all
		@recs = @allrecs;
		}
	}

# Actually show the records
if ($in{'type'} eq "ALL") {
	@recs = grep { $_->{'type'} ne "SOA" } @recs
	}
else {
	@recs = grep { $_->{'type'} eq $in{'type'} } @recs
	}

my %hmap;
if (@recs) {
	@recs = &sort_records(@recs);
	foreach my $v (sort { $a cmp $b } keys %text) {
		if ($v =~ /^value_([A-Z0-9]+)(\d+)$/) {
			$hmap{$1}->[$2-1] = $text{$v};
			}
		}
	my @links = ( );
	if (!$access{'ro'} && $type eq 'master') {
		print &ui_form_start("delete_recs.cgi", "post");
		print &ui_hidden("zone", $in{'zone'}),"\n";
		print &ui_hidden("view", $in{'view'}),"\n";
		print &ui_hidden("type", $in{'type'}),"\n";
		print &ui_hidden("sort", $in{'sort'}),"\n";
		@links = ( &select_all_link("d", $form),
			   &select_invert_link("d", $form) );
		}
	print &ui_links_row(\@links);
	print &recs_table(@recs);
	print &ui_links_row(\@links);
	if (!$access{'ro'} && $type eq 'master') {
		print &ui_submit($text{'recs_delete'}),"\n";
		if ($in{'type'} eq 'A' || $in{'type'} eq 'AAAA') {
			print &ui_checkbox("rev", 1, $text{'recs_drev'},
					   $config{'rev_def'} != 1),"\n";
			}
		print &ui_form_end();
		}
	}
elsif ($in{'search'}) {
	# Show error message about no search results
	print "<b>$text{'recs_nosearch'}</b><p>\n";
	}
elsif ($config{'largezones'}) {
	# Do a search to show records
	print "<b>$text{'recs_needsearch'}</b><p>\n";
	}
elsif (!$shown_create_form) {
	# Show error message about no records
	print "<b>",&text('recs_none', $typedesc),"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'},
	"edit_$type.cgi?zone=$in{'zone'}&view=$in{'view'}",
	$text{'recs_return'});

sub recs_table
{
my $rv;

# Generate header, with correct columns for record type
my (@hcols, @tds);
if (!$access{'ro'} && $type eq 'master') {
	push(@hcols, "");
	push(@tds, "width=5");
	}
push(@hcols, &ui_link("edit_recs.cgi?zone=$in{'zone'}&view=$in{'view'}&type=$in{'type'}&sort=1", ($in{'type'} eq "PTR" ? $text{'recs_addr'} : $text{'recs_name'}) ) );
push(@hcols, &ui_link("edit_recs.cgi?zone=$in{'zone'}&view=$in{'view'}&type=$in{'type'}&sort=5", $text{'recs_type'}) ) if ($in{'type'} eq "ALL");
push(@hcols, $text{'recs_ttl'});
my @hmap = $hmap{$in{'type'}} ? @{$hmap{$in{'type'}}} : ( );
foreach my $h (@hmap) {
	push(@hcols, &ui_link("edit_recs.cgi?zone=$in{'zone'}&view=$in{'view'}&type=$in{'type'}&sort=2",$h) );
	}
if ($in{'type'} eq "ALL" || $is_extra{$in{'type'}}) {
	push(@hcols, $text{'recs_vals'});
	}
if ($config{'allow_comments'} && $in{'type'} ne "WKS") {
	push(@hcols, &ui_link("edit_recs.cgi?zone=$in{'zone'}&view=$in{'view'}&type=$in{'type'}&sort=4", $text{'recs_comment'}) );
	}
$rv .= &ui_columns_start(\@hcols, 100, 0, \@tds);

# Show the actual records
for(my $i=0; $i<@_; $i++) {
	my $r = $_[$i];
	my $name;
	if ($in{'type'} eq "PTR") {
		$name = &ip6int_to_net(&arpa_to_ip($r->{'name'}));
		}
	else {
		$name = $r->{'name'};
		}
	my @cols;
	$name = &html_escape($name);
	my $id = &record_id($r);
	if (!$access{'ro'} && $type eq 'master') {
		push(@cols, &ui_link("edit_record.cgi?zone=$in{'zone'}&id=".&urlize($id)."&num=$r->{'num'}&type=$in{'type'}&sort=$in{'sort'}&view=$in{'view'}", $name) );
		}
	else {
		push(@cols, $name);
		}
	if ($in{'type'} eq 'ALL') {
		push(@cols, $r->{'type'});
		}
	my $ttl = $r->{'realttl'};
	if ($ttl && $ttl =~ /(\d+)([SMHDW]?)/i) {
		$ttl =~ s/S//i;
		if ($ttl =~ s/M//i) { $ttl *= 60; }
		if ($ttl =~ s/H//i) { $ttl *= 3600; }
		if ($ttl =~ s/D//i) { $ttl *= 86400; }
		if ($ttl =~ s/W//i) { $ttl *= 604800; }
		}
	push(@cols, $ttl ? &html_escape($ttl) : $text{'default'});
	for(my $j=0; $j<@hmap; $j++) {
		my $v;
		if ($in{'type'} eq "RP" && $j == 0) {
			$v .= &dotted_to_email($r->{'values'}->[$j]);
			}
		elsif ($in{'type'} eq "WKS" && $j == @hmap-1) {
			for(my $k=$j; $r->{'values'}->[$k]; $k++) {
				$v .= $r->{'values'}->[$k];
				$v .= ' ';
				}
			}
		elsif ($in{'type'} eq "LOC") {
			$v = join(" ", @{$r->{'values'}});
			}
		elsif ($in{'type'} eq "KEY" && $j == 3) {
			$v = substr($r->{'values'}->[$j], 0, 20)."...";
			}
		else {
			$v = $r->{'values'}->[$j];
			if ($in{'type'} eq "TLSA") {
				# Display TLSA codes nicely
				if ($j == 0) {
					$v = $text{'tlsa_usage'.$v};
					}
				elsif ($j == 1) {
					$v = $text{'tlsa_selector'.$v};
					}
				elsif ($j == 2) {
					$v = $text{'tlsa_match'.$v};
					}
				else {
					$v = undef;
					}
				$v = $v ? $v." (".$r->{'values'}->[$j].")"
					: $r->{'values'}->[$j];
				}
			elsif ($in{'type'} eq "SSHFP") {
				# Display SSHFP codes nicely
				if ($j == 0) {
					$v = $text{'sshfp_alg'.$v};
					}
				elsif ($j == 1) {
					$v = $text{'sshfp_fp'.$v};
					}
				else {
					$v = undef;
					}
				$v = $v ? $v." (".$r->{'values'}->[$j].")"
					: $r->{'values'}->[$j];
				}
			elsif ($in{'type'} eq "CAA") {
				if ($j == 0) {
					$v = $v ? $text{'yes'} : $text{'no'};
					}
				elsif ($j == 1) {
					$v = $text{'value_caa_'.$v} || $v;
					}
				}
			elsif ($in{'type'} eq "NSEC3PARAM" && $j == 3) {
				$v = $text{'value_NSEC3PARAM4_none'}
					if ($v eq "-");
				}
			}
		if (length($v) > 80) {
			$v = substr($v, 0, 80)." ...";
			}
		$v = &html_escape($v);
		push(@cols, $v);
		}
	if ($in{'type'} eq "ALL" || $is_extra{$in{'type'}}) {
		my $joined = join(" ", @{$r->{'values'}});
		if (length($joined) > 80) {
			$joined = substr($joined, 0, 80)." ...";
			}
		push(@cols, $joined);
		}
	if ($config{'allow_comments'} && $in{'type'} ne "WKS") {
		push(@cols, &html_escape($r->{'comment'}));
		}
	if (!$access{'ro'} && $type eq 'master') {
		$rv .= &ui_checked_columns_row(\@cols, \@tds,
					      "d", $r->{'num'}."/".$id);
		}
	else {
		$rv .= &ui_columns_row(\@cols, \@tds);
		}
	}
$rv .= &ui_columns_end();
return $rv;
}

