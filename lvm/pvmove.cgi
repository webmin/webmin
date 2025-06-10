#!/usr/local/bin/perl
# Move LV data off a PV

require './lvm-lib.pl';
&ReadParse();
&error_setup($text{'pvmove_err'});

# Get the LV
($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
$vg || &error($text{'vg_egone'});
@lvs = &list_logical_volumes($in{'vg'});
($lv) = grep { $_->{'name'} eq $in{'lv'} } @lvs;
$lv || &error($text{'lv_egone'});

# Validate inputs
$in{'from'} ne $in{'to'} || &error($text{'pvmove_efrom'});

$vgdesc = &text('lv_vg', $vg->{'name'});
&ui_print_unbuffered_header($vgdesc, $text{'pvmove_title'}, "");

# Do the move
print &text('pvmove_start', "<tt>$lv->{'name'}</tt>",
	    "<tt>$in{'from'}</tt>", "<tt>$in{'to'}</tt>"),"<p>\n";
print "<pre>";
$err = &move_logical_volume($lv, $in{'from'}, $in{'to'}, 1);
print "</pre>";
if ($err) {
	print $text{'pvmove_failed'},"<p>\n";
	}
else {
	print $text{'pvmove_done'},"<p>\n";
	}

&ui_print_footer("index.cgi?mode=lvs", $text{'index_return'});
