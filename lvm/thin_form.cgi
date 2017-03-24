#!/usr/local/bin/perl
# Display a form for creating a new thinpool from two LVs

require './lvm-lib.pl';
&ReadParse();
($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
$vg || &error($text{'vg_egone'});

# Find LVs that aren't in use
my @lvs;
foreach my $lv (&list_logical_volumes($in{'vg'})) {
	next if ($lv->{'is_snap'});
	my @stat = &device_status($lv->{'device'});
	next if (@stat);
	push(@lvs, $lv);
	}
@lvs || &error($text{'thin_elvs'});
@lvsel = map { [ $_->{'name'},
		 $_->{'name'}." (".&nice_size($_->{'size'} * 1024).")" ] } @lvs;

$vgdesc = &text('lv_vg', $vg->{'name'});
&ui_print_header($vgdesc, $text{'thin_title'}, "");

print $text{'thin_desc'},"<p>\n";

print &ui_form_start("thin_create.cgi", "post");
print &ui_hidden("vg", $in{'vg'});
print &ui_table_start($text{'thin_header'}, undef, 2);

# Data LV
print &ui_table_row($text{'thin_datalv'},
	&ui_select("data", undef, \@lvsel));

# Metadata LV
print &ui_table_row($text{'thin_metadatalv'},
	&ui_select("metadata", undef, \@lvsel));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'thin_ok'} ] ]);

&ui_print_footer("index.cgi?mode=lvs", $text{'index_return'});
