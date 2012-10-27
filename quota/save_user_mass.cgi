#!/usr/local/bin/perl
# Actually update the users

require './quota-lib.pl';
&ReadParse();
&error_setup($text{'umass_err'});
$fs = $in{'dir'};
@d = split(/\0/, $in{'d'});
foreach $u (@d) {
	&can_edit_user($u) ||
		&error(&text('euser_eallowus', $u));
	}
$access{'ro'} && &error(&text('euser_eallowus', $u));
&can_edit_filesys($fs) ||
	&error($text{'euser_eallowfs'});

# Validate inputs
foreach $t ('sblocks', 'hblocks', 'sfiles', 'hfiles') {
	$in{$t."_def"} != 2 || $in{$t} =~ /^\d+(\.\d+)?$/ ||
		&error($text{'umass_e'.$t});
	}

# Update the users
$bsize = &block_size($fs);
$n = &filesystem_users($fs);
foreach $u (@d) {
	# Find the user
	@uinfo = ( );
	for($i=0; $i<$n; $i++) {
		if ($user{$i,'user'} eq $u) {
			@uinfo = ( $user{$i,'sblocks'}, $user{$i,'hblocks'},
				   $user{$i,'sfiles'},  $user{$i,'hfiles'} );
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

		# Update the user
		&edit_user_quota($u, $fs, @uinfo);
		}
	}

&redirect("list_users.cgi?dir=".&urlize($fs));

