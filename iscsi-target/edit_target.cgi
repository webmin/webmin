#!/usr/local/bin/perl
# Show a form to edit or create a target

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-target-lib.pl';
our (%text, %in);
&ReadParse();
my $conf = &get_iscsi_config();

# Get the target and show page header
my $target;
if ($in{'new'}) {
	&ui_print_header(undef, $text{'target_title1'}, "");
	$target = { 'members' => [ ] };
	}
else {
	&ui_print_header(undef, $text{'target_title2'}, "");
	($target) = grep { $_->{'value'} eq $in{'name'} }
			 &find($conf, "Target");
	$target || &error($text{'target_egone'});
	}

print &ui_form_start("save_target.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("oldname", $in{'name'});
print &ui_table_start($text{'target_header'}, undef, 2);

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
my @luns = &find_value($target->{'members'}, "Lun");
for(my $i=0; $i<@luns+1; $i++) {
	my ($lunid, $lunstr) = split(/\s+/, $luns[$i]);
	my %lunopts = map { split(/=/, $_) } split(/,/, $lunstr);

	my @opts;

	# Start with option for no device
	my $none_found = 0;
	if ($i > 0) {
		push(@opts, [ 'none', $text{'target_none'} ]);
		$none_found = 1 if (!$lunopts{'Path'} && !$lunopts{'Sectors'});
		}

	# Add regular partitions
	my $part_found = 0;
	my $sel = &fdisk::partition_select("part".$i, $lunopts{'Path'}, 0,
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
			$raid_found = 1 if ($lunopts{'Path'} eq $c->{'value'});
			}
		}
	if (@ropts) {
		push(@opts, [ 'raid', $text{'target_raid'},
		      &ui_select("raid".$i, $lunopts{'Path'}, \@ropts) ]);
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
		$lvm_found = 1 if (&same_file($lunopts{'Path'},$l->{'device'}));
		}
	if (@lopts) {
		push(@opts, [ 'lvm', $text{'target_lvm'},
		      &ui_select("lvm".$i, $lunopts{'Path'}, \@lopts) ]);
		}

	# Add special null-IO mode
	my $null_found = 0;
	push(@opts, [ 'null', $text{'target_null'},
		      &ui_textbox("null".$i, $lunopts{'Sectors'}, 10)." ".
		      $text{'target_sectors'} ]);
	$null_found = 1 if ($lunopts{'Type'} eq 'nullio');

	# Then add other file mode
	my $mode = $part_found ? 'part' :
		   $raid_found ? 'raid' :
		   $none_found ? 'none' :
		   $null_found ? 'null' :
		   $lvm_found ? 'lvm' : 'other';
	push(@opts, [ 'other', $text{'target_other'},
		      &ui_textbox("other".$i,
			  $mode eq 'other' ? $lunopts{'Path'} : "", 50).
		      " ".&file_chooser_button("other") ]);

	# Options for this lun
	my @grid;
	push(@grid, "<b>".$text{'target_type'}."</b>",
		    &ui_select("type".$i, $lunopts{'Type'} || "fileio",
			       [ [ 'fileio', $text{'target_fileio'} ],
			         [ 'blockio', $text{'target_blockio'} ] ]));
	push(@grid, "<b>".$text{'target_iomode'}."</b>",
		    &ui_select("iomode".$i, $lunopts{'IOMode'},
			       [ [ '', $text{'target_wt'} ],
				 [ 'wb', $text{'target_wb'} ],
				 [ 'ro', $text{'target_ro'} ] ]));

	print &ui_table_row(&text('target_lun', $i+1),
		&ui_radio_table("mode".$i, $mode, \@opts)."\n".
		&ui_grid_table(\@grid, 2));
	}

print &ui_table_hr();

# Incoming user(s)
my @iusers = &find_value($target->{'members'}, "IncomingUser");
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
	$utable);

# Outgoing user
my $u = &find_value($target->{'members'}, "OutgoingUser");
my ($uname, $upass) = split(/\s+/, $u);
print &ui_table_row($text{'target_ouser'},
	&ui_radio("ouser_def", $u ? 0 : 1,
		  [ [ 1, $text{'target_ousernone'} ],
		    [ 0, $text{'target_ousername'} ] ])." ".
	&ui_textbox("ouser", $uname, 30)." ".
	$text{'target_ouserpass'}." ".
	&ui_textbox("opass", $upass, 20));

print &ui_table_hr();

# Optional alias name
my $a = &find_value($target->{'members'}, "Alias");
print &ui_table_row($text{'target_alias'},
	&ui_opt_textbox("alias", $a, 20, $text{'target_noalias'}));

# Header digest mode
my $h = &find_value($target->{'members'}, "HeaderDigest");
print &ui_table_row($text{'target_hdigest'},
	&ui_select("hdigest", $h,
		   [ [ "", $text{'target_nodigest'} ],
		     [ "CRC32C" ] ], 1, 0, 1));

# Data digest mode
$h = &find_value($target->{'members'}, "DataDigest");
print &ui_table_row($text{'target_ddigest'},
	&ui_select("ddigest", $h,
		   [ [ "", $text{'target_nodigest'} ],
		     [ "CRC32C" ] ], 1, 0, 1));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});
