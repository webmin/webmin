#!/usr/local/bin/perl
# Update visible right-frame sections

require "gray-theme/gray-theme-lib.pl";
require "gray-theme/theme.pl";

&ReadParse();
&error_setup($text{'edright_err'});
&load_theme_library();
($hasvirt, $level, $hasvm2) = &get_virtualmin_user_level();
$sects = &get_right_frame_sections();
!$sects->{'global'} ||
   $hasvirt && &virtual_server::master_admin() ||
   $hasvm2 && !$server_manager::access{'owner'} ||
	&error($text{'edright_ecannot'});

# Validate and store
foreach $s (&list_right_frame_sections()) {
	$sect->{'no'.$s->{'name'}} = !$in{$s->{'name'}};
	}
if ($in{'alt_def'}) {
	delete($sect->{'alt'});
	}
else {
	$in{'alt'} =~ /^(http|https|\/)/ || &error($text{'edright_ealt'});
	$sect->{'alt'} = $in{'alt'};
	}
$sect->{'list'} = $in{'list'};
$sect->{'tab'} = $in{'tab'};
if ($in{'fsize_def'}) {
	delete($sect->{'fsize'});
	}
else {
	$in{'fsize'} =~ /^\d+$/ || &error($text{'edright_efsize'});
	$sect->{'fsize'} = $in{'fsize'};
	}
$sect->{'nosearch'} = !$in{'search'};
if ($hasvirt) {
	$sect->{'dom'} = $in{'dom'};
	$sect->{'qsort'} = $in{'qsort'};
	$sect->{'qshow'} = $in{'qshow'};
	if ($in{'max_def'}) {
		delete($sect->{'max'});
		}
	else {
		$in{'max'} =~ /^[1-9]\d*$/ || &error($text{'edright_emax'});
		$sect->{'max'} = $in{'max'};
		}
	}
if ($hasvm2) {
	$sect->{'server'} = $in{'server'};
	}
if ($hasvirt && &virtual_server::master_admin() ||
     $hasvm2 && &server_manager::can_action(undef, "global")) {
	$sect->{'global'} = $in{'global'};
	$sect->{'nowebmin'} = $in{'nowebmin'};
	}

# Save config
&save_right_frame_sections($sect);
&redirect("right.cgi");

