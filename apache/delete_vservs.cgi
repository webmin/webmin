#!/usr/local/bin/perl
# Delete a bunch of virtual servers

require './apache-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});
$access{'vaddr'} || &error($text{'delete_ecannot'});
$conf = &get_config();
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Get them all
foreach $d (sort { $b <=> $a } @d) {
	($vmembers, $vconf) = &get_virtual_config($d);
	&can_edit_virt($vconf) || &error(&text('delete_ecannot2',
					       &virtual_name($vconf)));
	push(@virts, $vconf);
	}

# Take them out of their files
&before_changing();
foreach $vconf (@virts) {
	&lock_file($vconf->{'file'});
	$lref = &read_file_lines($vconf->{'file'});
	if ($vconf->{'line'} && $lref->[$vconf->{'line'}-1] !~ /\S/) {
		# Remove one blank line before vserv
		$vconf->{'line'}--;
		}
	splice(@$lref, $vconf->{'line'},
	       $vconf->{'eline'} - $vconf->{'line'} + 1);
	$nonblank = 0;
	foreach $l (@$lref) {
		$nonblank++ if ($l =~ /\S/);
		}
	&flush_file_lines();
	if (!$nonblank) {
		# Can lose the entire file
		unlink($vconf->{'file'});

		# Delete the link too
		&delete_webfile_link($vconf->{'file'});
		}
	}
&unlock_all_files();
&after_changing();
&webmin_log("virts", "delete", scalar(@virts));
&redirect("");

