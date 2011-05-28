#!/usr/local/bin/perl
# edit_recs.cgi
# Display records of some type from some domain

require './bind8-lib.pl';
&ReadParse();
$zone = &get_zone_name($in{'index'}, $in{'view'});
$dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'recs_ecannot'});
&can_edit_type($in{'type'}, \%access) ||
	&error($text{'recs_ecannottype'});
$desc = &text('recs_header', &ip6int_to_net(&arpa_to_ip($dom)));
$typedesc = $text{"recs_$in{'type'}"} || $in{'type'};
&ui_print_header($desc, &text('recs_title', $typedesc), "",
		 undef, undef, undef, undef, &restart_links($zone));

# Show form for adding a record
$type = $zone->{'type'};
$file = $zone->{'file'};
$form = 0;
if (!$access{'ro'} && $type eq 'master' && $in{'type'} ne 'ALL') {
	&record_input($in{'index'}, $in{'view'}, $in{'type'}, $file, $dom,
		      undef, undef, $in{'newname'}, $in{'newvalue'});
	$form++;
	$shown_create_form = 1;
	}

if ($config{'largezones'}) {
	# Show search form
	print &ui_form_start("edit_recs.cgi");
	print &ui_hidden("index", $in{'index'}),"\n";
	print &ui_hidden("view", $in{'view'}),"\n";
	print &ui_hidden("type", $in{'type'}),"\n";
	print "<b>$text{'recs_find'}</b>\n";
	print &ui_textbox("search", $in{'search'}, 20),"\n";
	print &ui_submit($text{'recs_search'}),"\n";
	print &ui_form_end();
	$form++;
	}

if (!$config{'largezones'} || $in{'search'}) {
	# Get all records
	@allrecs = grep { !$_->{'generate'} && !$_->{'defttl'} }
		     &read_zone_file($file, $dom);
	if ($in{'search'}) {
		# Limit to records matching some search
		foreach $r (@allrecs) {
			if ($r->{'name'} =~ /\Q$in{'search'}\E/i) {
				push(@recs, $r);
				}
			else {
				foreach $v (@{$r->{'values'}}) {
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
if (@recs) {
	@recs = &sort_records(@recs);
	foreach $v (keys %text) {
		if ($v =~ /^value_([A-Z]+)(\d+)/) {
			$hmap{$1}->[$2-1] = $text{$v};
			}
		}
	@links = ( );
	if (!$access{'ro'} && $type eq 'master') {
		print &ui_form_start("delete_recs.cgi", "post");
		print &ui_hidden("index", $in{'index'}),"\n";
		print &ui_hidden("view", $in{'view'}),"\n";
		print &ui_hidden("type", $in{'type'}),"\n";
		print &ui_hidden("sort", $in{'sort'}),"\n";
		@links = ( &select_all_link("d", $form),
			   &select_invert_link("d", $form) );
		}
	print &ui_links_row(\@links);
	if ($in{'type'} =~ /HINFO|WKS|RP|KEY|LOC|SPF/ ||
	    $config{'allow_comments'}) {
		# One-column table
		print &recs_table(@recs);
		}
	else {
		# Two-column table
		$mid = int((@recs+1)/2);
		@grid = ( );
		push(@grid, &recs_table(@recs[0 .. $mid-1]));
		if ($mid < @recs) {
			push(@grid, &recs_table(@recs[$mid .. $#recs]));
			}
		print &ui_grid_table(\@grid, 2, 100,
			[ "width=50%", "width=50%" ]);
		}
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
elsif (!$shown_create_form) {
	# Show error message
	print "<b>",&text('recs_none', $typedesc),"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'},
	"edit_$type.cgi?index=$in{'index'}&view=$in{'view'}",
	$text{'recs_return'});

sub recs_table
{
my ($r, $i, $j, $k, $h);
my $rv;

# Generate header, with correct columns for record type
local (@hcols, @tds);
if (!$access{'ro'} && $type eq 'master') {
	push(@hcols, "");
	push(@tds, "width=5");
	}
push(@hcols, "<a href='edit_recs.cgi?index=$in{'index'}&view=$in{'view'}&type=$in{'type'}&sort=1'>".($in{'type'} eq "PTR" ? $text{'recs_addr'} : $text{'recs_name'})."</a>");
push(@hcols, "<a href='edit_recs.cgi?index=$in{'index'}&view=$in{'view'}&type=$in{'type'}&sort=5'>$text{'recs_type'}</a>") if ($in{'type'} eq "ALL");
push(@hcols, $text{'recs_ttl'});
@hmap = @{$hmap{$in{'type'}}};
foreach $h (@hmap) {
	push(@hcols, "<a href='edit_recs.cgi?index=$in{'index'}&view=$in{'view'}&type=$in{'type'}&sort=2'>$h</a>");
	}
if ($in{'type'} eq "ALL" || $is_extra{$in{'type'}}) {
	push(@hcols, $text{'recs_vals'});
	}
if ($config{'allow_comments'} && $in{'type'} ne "WKS") {
	push(@hcols, "<a href='edit_recs.cgi?index=$in{'index'}&view=$in{'view'}&type=$in{'type'}&sort=4'>$text{'recs_comment'}</a>");
	}
$rv .= &ui_columns_start(\@hcols, 100);

# Show the actual records
for($i=0; $i<@_; $i++) {
	$r = $_[$i];
	if ($in{'type'} eq "PTR") {
		$name = &ip6int_to_net(&arpa_to_ip($r->{'name'}));
		}
	elsif ($in{'type'} eq "SRV") {
		$name = $r->{'name'};
		$name =~ s/^_//;
		$name =~ s/\._/\./;
		}
	else {
		$name = $r->{'name'};
		}
	local @cols;
	$name = &html_escape($name);
	$id = &record_id($r);
	if (!$access{'ro'} && $type eq 'master') {
		push(@cols, 
		      "<a href=\"edit_record.cgi?index=".
		      "$in{'index'}&id=".&urlize($id)."&num=$r->{'num'}&".
		      "type=$in{'type'}&sort=$in{'sort'}&view=$in{'view'}\">".
		      "$name</a>");
		}
	else {
		push(@cols, $name);
		}
	if ($in{'type'} eq 'ALL') {
		push(@cols, $r->{'type'});
		}
	if ($r->{'ttl'} =~ /(\d+)([SMHDW]?)/i) {
		$r->{'ttl'} =~ s/S//i;
		if ($r->{'ttl'} =~ s/M//i) { $r->{'ttl'} *= 60; }
		if ($r->{'ttl'} =~ s/H//i) { $r->{'ttl'} *= 3600; }
		if ($r->{'ttl'} =~ s/D//i) { $r->{'ttl'} *= 86400; }
		if ($r->{'ttl'} =~ s/W//i) { $r->{'ttl'} *= 604800; }
		}
	push(@cols, $r->{'ttl'} ? &html_escape($r->{'ttl'}) : $text{'default'});
	for($j=0; $j<@hmap; $j++) {
		local $v;
		if ($in{'type'} eq "RP" && $j == 0) {
			$v .= &convert_illegal(
				&dotted_to_email($r->{'values'}->[$j]));
			}
		elsif ($in{'type'} eq "WKS" && $j == @hmap-1) {
			for($k=$j; $r->{'values'}->[$k]; $k++) {
				$v .= &convert_illegal($r->{'values'}->[$k]);
				$v .= ' ';
				}
			}
		elsif ($in{'type'} eq "LOC") {
			$v = &convert_illegal(join(" ", @{$r->{'values'}}));
			}
		elsif ($in{'type'} eq "KEY" && $j == 3) {
			$v = substr($r->{'values'}->[$j], 0, 20)."...";
			}
		else {
			$v = &convert_illegal($r->{'values'}->[$j]);
			}
		if (length($v) > 80) {
			$v = substr($v, 0, 80)." ...";
			}
		push(@cols, $v);
		}
	if ($in{'type'} eq "ALL" || $is_extra{$in{'type'}}) {
		$joined = join(" ", @{$r->{'values'}});
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

