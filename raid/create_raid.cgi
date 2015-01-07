#!/usr/local/bin/perl
# create_raid.cgi
# Create raid set

require './raid-lib.pl';
&ReadParse();
&lock_raid_files();
$conf = &get_raidtab();

# Build config file structure
&error_setup($text{'create_err'});
$raid = { 'name' => 'raiddev',
	  'value' => $in{'device'},
	  'members' => \@members };
push(@members, { 'name' => 'raid-level',
		 'value' => $in{'level'} } );
push(@members, { 'name' => 'persistent-superblock',
		 'value' => $in{'super'} } );
if ($in{'layout'}) {
	push(@members, { 'name' => 'parity-algorithm',
			 'value' => $in{'layout'} } );
	}
if ($in{'chunk'}) {
	push(@members, { 'name' => 'chunk-size',
			 'value' => $in{'chunk'} } );
	}

# Add RAID disks
@disks = split(/\0/, $in{'disks'});
if (!@disks) {
	&error($text{'create_edisks'});
	}
elsif ($in{'level'} == 1 && scalar(@disks)+$in{'missing'} < 2) {
	&error($text{'create_edisks2'});
	}
push(@members, { 'name' => 'nr-raid-disks',
		 'value' => scalar(@disks)+($in{'pdisk'} ? 1 : 0) } );
for($i=0; $i<@disks; $i++) {
	push(@members, { 'name' => 'device',
			 'value' => $disks[$i],
			 'members' => [ { 'name' => 'raid-disk',
					  'value' => $i } ] } );
	}

# Add spares
@spares = split(/\0/, $in{'spares'});
if (@spares) {
	push(@members, { 'name' => 'nr-spare-disks',
			 'value' => scalar(@spares) } );
	for($i=0; $i<@spares; $i++) {
		if (&indexof($spares[$i], @disks) != -1) {
			&error(&text('create_espare', $spares[$i]));
			}
		push(@members, { 'name' => 'device',
				 'value' => $spares[$i],
				 'members' => [ { 'name' => 'spare-disk',
						  'value' => $i } ] } );
		}
	}

# Add parity disk
if ($in{'pdisk'}) {
	&indexof($in{'pdisk'}, @disks) < 0 || &error($text{'create_epdisk'});
	push(@members, { 'name' => 'device',
			 'value' => $in{'pdisk'},
			 'members' => [ { 'name' => 'parity-disk',
					  'value' => 0 } ] } );
	}

# Parse spare group
if ($in{'group_mode'} == 1) {
	push(@members, { 'name' => 'spare-group',
			 'value' => $in{'group'} });
	}
elsif ($in{'group_mode'} == 2) {
	$in{'newgroup'} =~ /^[a-z0-9\_]+$/i ||
		&error($text{'create_enewgroup'});
	push(@members, { 'name' => 'spare-group',
			 'value' => $in{'newgroup'} });
	}

if ($raid_mode eq "raidtools") {
	# Create config before actually creating RAID.
	&create_raid($raid);
	}

if ($err = &make_raid($raid, $in{'force'}, $in{'missing'}, $in{'assume'})) {
	if ($raid_mode eq "raidtools") {
		&delete_raid($raid);
		}
	&error($err);
	}
elsif ($raid_mode eq "mdadm") {
	# Create config after actually creating RAID to be able to get UUID.
	$uuid = &get_uuid($raid);
	&create_raid($raid, $uuid);
	if ($in{'level'} != 0) {
		# Set RAID to read/write mode after creation except for RAID0 which is automatically set to read/write.
		&readwrite_raid($raid);
		}
	}

&unlock_raid_files();

&webmin_log("create", undef, $in{'device'}, \%in);
&redirect("");

