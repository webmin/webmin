#!/usr/local/bin/perl
# Actually update the groups

require './quota-lib.pl';
&ReadParse();
&error_setup($text{'gmass_err'});
$fs = $in{'dir'};
@d = split(/\0/, $in{'d'});
foreach $u (@d) {
	&can_edit_group($u) ||
		&error(&text('egroup_eallowgr', $u));
	}
$access{'ro'} && &error(&text('egroup_eallowgr', $u));
&can_edit_filesys($fs) ||
	&error($text{'euser_eallowfs'});

# Validate inputs
foreach $t ('sblocks', 'hblocks', 'sfiles', 'hfiles') {
	$in{$t."_def"} != 2 || $in{$t} =~ /^\d+(\.\d+)?$/ ||
		&error($text{'umass_e'.$t});
	}

# Update the groups
$bsize = &block_size($fs);
$n = &filesystem_groups($fs);
foreach $u (@d) {
	# Find the group
	@uinfo = ( );
	for($i=0; $i<$n; $i++) {
		if ($group{$i,'group'} eq $u) {
			@uinfo = ( $group{$i,'sblocks'}, $group{$i,'hblocks'},
				   $group{$i,'sfiles'},  $group{$i,'hfiles'} );
			last;
			}
		}

	# Update his object
	if (@uinfo) {
		if ($in{'sblocks_def'} == 1) {
			$uinfo[0] = 0;
			}
		elsif ($in{'sblocks_def'} == 2) {
			$uinfo[0] = &quota_parse('sblocks', $bsize, 1);
			}
		if ($in{'hblocks_def'} == 1) {
			$uinfo[1] = 0;
			}
		elsif ($in{'hblocks_def'} == 2) {
			$uinfo[1] = &quota_parse('hblocks', $bsize, 1);
			}
		if ($in{'sfiles_def'} == 1) {
			$uinfo[2] = 0;
			}
		elsif ($in{'sfiles_def'} == 2) {
			$uinfo[2] = $in{'sfiles'};
			}
		if ($in{'hfiles_def'} == 1) {
			$uinfo[3] = 0;
			}
		elsif ($in{'hfiles_def'} == 2) {
			$uinfo[3] = $in{'hfiles'};
			}

		# Update the group
		&edit_group_quota($u, $fs, @uinfo);
		}
	}

&redirect("list_groups.cgi?dir=".&urlize($fs));

