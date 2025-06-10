#!/usr/local/bin/perl
# raid_form.cgi
# Display a form for creating a raid device

require './raid-lib.pl';
&foreign_require("mount");
&foreign_require("lvm");
&ReadParse();
$conf = &get_raidtab();

# Create initial object
foreach $c (@$conf) {
	if ($c->{'value'} =~ /md(\d+)$/) {
		$taken{$1} = 1;
		}
	}
$max = 0;
while($taken{$max}) {
	$max++;
	}
$raid = { 'value' => "/dev/md$max",
	  'members' => [ { 'name' => 'raid-level',
			   'value' => $in{'level'} },
			 { 'name' => 'persistent-superblock',
			   'value' => 1 }
		       ] };

&ui_print_header(undef, $text{'create_title'}, "");

# Find available partitions
@disks = &find_free_partitions(undef, 1, 1);
if (!@disks) {
	print "<p><b>$text{'create_nodisks'}</b> <p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

print &ui_form_start("create_raid.cgi");
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'create_header'}, undef, 2);

# Device name
print &ui_table_row($text{'create_device'}, "<tt>$raid->{'value'}</tt>");
print &ui_hidden("device", $raid->{'value'});

# RAID level
$lvl = &find_value('raid-level', $raid->{'members'});
print &ui_table_row($text{'create_level'},
	$lvl eq 'linear' ? $text{'linear'} : $text{"raid$lvl"});
print &ui_hidden("level", $lvl);

# Create superblock?
$super = &find_value('persistent-superblock', $raid->{'members'});
print &ui_table_row($text{'create_super'},
	&ui_yesno_radio("super", $super ? 1 : 0));

# Layout
if ($lvl == 5 || $lvl == 6) {
	$layout = &find_value('parity-algorithm', $raid->{'members'});
	print &ui_table_row($text{'create_parity'},
		&ui_select("layout", $layout,
			[ [ '', $text{'default'} ],
			  'left-asymmetric', 'right-asymmetric',
			  'left-symmetric', 'right-symmetric',
			  'parity-first', 'parity-last' ]));
	}

if ($lvl == 10) {
	$layout = &find_value('parity-algorithm', $raid->{'members'});
	print &ui_table_row($text{'create_parity'},
		&ui_select("layout", $layout,
			[ [ '', $text{'default'} ],
			  [ 'n2', $text{'create_n2_layout'} ],
			  [ 'f2', $text{'create_f2_layout'} ],
			  [ 'o2', $text{'create_o2_layout'} ],
			  [ 'n3', $text{'create_n3_layout'} ],
			  [ 'f3', $text{'create_f3_layout'} ],
			  [ 'o3', $text{'create_o3_layout'} ] ]));
	}

# Chunk size
$chunk = &find_value('chunk-size', $raid->{'members'});
push(@chunks, [ '', $text{'default'} ]);
for($i=4; $i<=4096; $i*=2) { push(@chunks, [ $i, $i." kB" ]); }
print &ui_table_row($text{'create_chunk'},
	&ui_select("chunk", $chunk, \@chunks));

# Display partitions in raid, spares and parity
print &ui_table_row($text{'create_disks'},
	&ui_select("disks", undef, \@disks, 4, 1));

if ($lvl == 1 || $lvl == 4 || $lvl == 5 || $lvl == 6 || $lvl == 10) {
	print &ui_table_row($text{'create_spares'},
		&ui_select("spares", undef, \@disks, 4, 1));
	}

if ($lvl == 4 && $raid_mode ne 'mdadm') {
	print &ui_table_row($text{'create_pdisk'},
		&ui_select("pdisk", '', [ [ '', $text{'create_auto'} ],
					  @disks ], 4, 1));
	}

# Missing disk option
if ($lvl == 1 && $raid_mode eq 'mdadm') {
	print &ui_table_row($text{'create_missing'},
		&ui_yesno_radio("missing", 0));
	}

# Spare-group name option
if ($raid_mode eq 'mdadm') {
	@opts = ( [ 0, $text{'create_nogroup'} ] );
	@groups = ( );
	foreach $c (@$conf) {
		$sg = &find_value("spare-group", $c->{'members'});
		push(@groups, $sg) if ($sg);
		}
	if (@groups) {
		push(@opts, [ 1, $text{'create_oldgroup'},
			      &ui_select("group", undef, \@groups) ]);
		}
	push(@opts, [ 2, $text{'create_newgroup'},
		      &ui_textbox("newgroup", undef, 30) ]);
	print &ui_table_row($text{'create_group'},
		&ui_radio_table("group_mode", 0, \@opts, 1));
	}

# Force creation
print &ui_table_row($text{'create_force'},
	&ui_yesno_radio("force", 0));

# Assume clean
if ($raid_mode eq 'mdadm') {
	print &ui_table_row($text{'create_assume'},
		&ui_yesno_radio("assume", 0));
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("", $text{'index_return'});

