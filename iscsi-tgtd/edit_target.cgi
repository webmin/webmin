#!/usr/local/bin/perl
# Show a form to edit or create a target

use strict;
use warnings;
require './iscsi-tgtd-lib.pl';
our (%text, %in);
&ReadParse();
my $conf = &get_tgtd_config();

# Get the target and show page header
my $target;
if ($in{'new'}) {
	&ui_print_header(undef, $text{'target_title1'}, "");
	$target = { 'members' => [ ] };
	}
else {
	&ui_print_header(undef, $text{'target_title2'}, "");
	($target) = grep { $_->{'value'} eq $in{'name'} }
			 &find($conf, "target");
	$target || &error($text{'target_egone'});
	}

print &ui_form_start("save_target.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("oldname", $in{'name'});
print &ui_table_start($text{'target_header'}, undef, 4);

# Target name
my ($host, $tname);
if ($in{'new'}) {
	$host = &find_host_name($conf) || &generate_host_name();
	$tname = "";
	}
else {
	($host, $tname) = split(/:/, $target->{'value'});
	}
print &ui_table_row($text{'target_name'},
	"<tt>".$host.":</tt>".&ui_textbox("name", $tname, 30));

# Logical units it contains
my @luns = (&find($target->{'members'}, "backing-store"),
	    &find($target->{'members'}, "direct-store"));
@luns = sort { $a->{'file'} <=> $b->{'file'} } @luns;
push(@luns, { 'name' => 'backing-store',
	      'value' => '',
	      'values' => [] });
for(my $i=0; $i<@luns; $i++) {
	my $path = $luns[$i]->{'values'}->[0] || "";
	my @opts;

	# Start with option for no device
	my $none_found = 0;
	if ($i > 0) {
		push(@opts, [ 'none', $text{'target_none'} ]);
		$none_found = 1 if (!$path);
		}

	# Add regular partitions
	my $part_found = 0;
	my $sel = &fdisk::partition_select("part".$i, $path, 0,
					   \$part_found);
	push(@opts, [ 'part', $text{'target_part'}, $sel ]);

	# Then add RAID devices
	my $rconf = &raid::get_raidtab();
	my @ropts;
	my $raid_found = 0;
	foreach my $c (@$rconf) {
		if ($c->{'active'}) {
			push(@ropts, [ $c->{'value'},
				       &text('target_md',
					     substr($c->{'value'}, -1)) ]);
			$raid_found = 1 if ($path eq $c->{'value'});
			}
		}
	if (@ropts) {
		push(@opts, [ 'raid', $text{'target_raid'},
		      &ui_select("raid".$i, $path, \@ropts) ]);
		}

	# Then add LVM logical volumes
	my @vgs = sort { $a->{'name'} cmp $b->{'name'} }
		       &lvm::list_volume_groups();
	my @lvs;
	foreach my $v (@vgs) {
		push(@lvs, sort { $a->{'name'} cmp $b->{'name'} }
				&lvm::list_logical_volumes($v->{'name'}));
		}
	my @lopts;
	my $lvm_found = 0;
	foreach my $l (@lvs) {
		push(@lopts, [ $l->{'device'},
			       &text('target_lv', $l->{'vg'}, $l->{'name'}) ]);
		$lvm_found = 1 if (&same_file($path, $l->{'device'}));
		}
	if (@lopts) {
		push(@opts, [ 'lvm', $text{'target_lvm'},
		      &ui_select("lvm".$i, $path, \@lopts) ]);
		}

	# Then add other file mode
	my $mode = $part_found ? 'part' :
		   $raid_found ? 'raid' :
		   $none_found ? 'none' :
		   $lvm_found ? 'lvm' : 'other';
	push(@opts, [ 'other', $text{'target_other'},
		      &ui_textbox("other".$i,
			  $mode eq 'other' ? $path : "", 50).
		      " ".&file_chooser_button("other") ]);

	# Options for this lun
	my @grid;
	my $cache = &find_value($luns[$i], "write-cache");
	push(@grid, "<b>$text{'target_type'}</b>",
		    &ui_select("type".$i, $luns[$i]->{'name'},
			       [ [ 'backing-store', $text{'target_backing'} ],
				 [ 'direct-store', $text{'target_direct'} ] ]));
	push(@grid, "<b>$text{'target_cache'}</b>",
		    &ui_radio("cache".$i, $cache,
			      [ [ "on", $text{'yes'} ],
				[ "off", $text{'no'} ],
				[ "", $text{'default'} ] ]));

	print &ui_table_row(&text('target_lun', $i+1),
		&ui_radio_table("mode".$i, $mode, \@opts)."\n".
		&ui_grid_table(\@grid, 2), 3);
	}

print &ui_table_hr();

# Incoming user(s)
my @iusers = &find_value($target, "incominguser");
my $utable = &ui_columns_start([
		$text{'target_uname'},
		$text{'target_upass'},
		]);
my $i = 0;
foreach my $u (@iusers, "", "") {
	my ($uname, $upass) = split(/\s+/, $u);
	$utable .= &ui_columns_row([
		&ui_textbox("uname_$i", $uname, 30),
		&ui_textbox("upass_$i", $upass, 20),
		]);
	$i++;
	}
$utable .= &ui_columns_end();
print &ui_table_row($text{'target_iuser'},
	&ui_radio("iuser_def", @iusers ? 0 : 1,
		  [ [ 1, $text{'target_iuserall'} ],
		    [ 0, $text{'target_iuserbelow'} ] ])."<br>\n".
	$utable, 3);

# Outgoing user
my $u = &find_value($target, "outgoinguser");
my ($uname, $upass) = $u ? split(/\s+/, $u) : ( );
print &ui_table_row($text{'target_ouser'},
	&ui_radio("ouser_def", $u ? 0 : 1,
		  [ [ 1, $text{'target_ousernone'}."<br>" ],
		    [ 0, $text{'target_ousername'} ] ])." ".
	&ui_textbox("ouser", $uname, 20)." ".
	$text{'target_ouserpass'}." ".
	&ui_textbox("opass", $upass, 20), 3);

print &ui_table_hr();

# Allowed initiator address
my @a = &find_value($target, "initiator-address");
print &ui_table_row($text{'target_iaddress'},
	&ui_radio("iaddress_def", @a ? 0 : 1,
		  [ [ 1, $text{'target_iall'} ],
		    [ 0, $text{'target_ibelow'} ] ])."<br>\n".
	&ui_textarea("iaddress", join("\n", @a), 3, 20));

# Allowed initiator name
my @n = &find_value($target, "initiator-name");
print &ui_table_row($text{'target_iname'},
	&ui_radio("iname_def", @n ? 0 : 1,
		  [ [ 1, $text{'target_iall'} ],
		    [ 0, $text{'target_ibelow'} ] ])."<br>\n".
	&ui_textarea("iname", join("\n", @n), 3, 20));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});
