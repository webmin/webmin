#!/usr/local/bin/perl
# Delete a bunch of virtual servers

require './apache-lib.pl';
&ReadParse();
@d = split(/\0/, $in{'d'});
$file_action = $in{'toggle'} ? "toggle" : undef;
&error_setup($file_action ? $text{'enable_err'} : $text{'delete_err'});
$access{'vaddr'} || &error($text{'delete_ecannot'});
$conf = &get_config();
$can_vhost_files = &can_manage_vhost_files();
@d || &error($text{'delete_enone'});

if ($file_action) {
	&can_manage_vhost_files() || &error($text{'enable_elinkdir'});
	foreach $d (@d) {
		if ($d =~ /^file\t([^\t]+)/) {
			$file = $1;
			}
		elsif ($d !~ /^file\t/) {
			($vmembers, $vconf) = &get_virtual_config($d);
			next if (!$vconf || !&can_edit_virt($vconf));
			$file = $vconf->{'file'};
			}
		else {
			next;
			}
		$rfile = $file ? &simplify_path(&resolve_links($file)) : undef;
		$files{$rfile}++ if ($rfile && -f $rfile &&
				      &can_manage_vhost_state_file($rfile));
		}
	@files = keys %files;
	@files || &error($text{'enable_enone'});
	foreach $file (@files) {
		$action = &vhost_file_toggle_action($file);
		$err = &virtualmin_vhost_file_state_error($file, $action);
		$err && &error($err);
		$file_actions{$file} = $action;
		}
	foreach $file (@files) {
		$err = $file_actions{$file} eq "enable" ?
			&enable_vhost_file($file) :
			&disable_vhost_file($file);
		$err && &error($err);
		}
	&webmin_log($file_action, "vhostfile", scalar(@files));
	&redirect("");
	exit;
	}
if (!$in{'delete'}) {
	&error($text{'delete_eaction'});
	}

# Get them all
foreach $d (@d) {
	if ($d =~ /^file\t([^\t]+)\t(\d+)$/) {
		push(@{$file_lines{$1}}, $2);
		next;
		}
	elsif ($d =~ /^file\t/) {
		next;
		}
	($vmembers, $vconf) = &get_virtual_config($d);
	$vconf || &error($text{'delete_egone'});
	&can_edit_virt($vconf) || &error(&text('delete_ecannot2',
					       &virtual_name($vconf)));
	$can_vhost_files && &is_default_vhost($vconf) &&
		&error($text{'delete_edefault'});
	push(@virts, $vconf);
	}
if (%file_lines) {
	foreach $file (keys %file_lines) {
		$rfile = &simplify_path(&resolve_links($file));
		next if (!$rfile || !-f $rfile ||
			 !&can_manage_vhost_state_file($rfile));
		@fvirts = &find_virtuals_in_file($rfile);
		foreach $line (@{$file_lines{$file}}) {
			($vconf) = grep { $_->{'line'} == $line } @fvirts;
			$vconf || &error($text{'delete_egone'});
			&can_edit_virt($vconf) ||
				&error(&text('delete_ecannot2',
					     &virtual_name($vconf)));
			&is_default_vhost($vconf) &&
				&error($text{'delete_edefault'});
			push(@{$file_virts{$rfile}}, $vconf);
			}
		}
	}
@virts || %file_virts || &error($text{'delete_enone'});

# Delete their structures
&before_changing(keys %file_virts);
foreach $vconf (@virts) {
	&lock_file($vconf->{'file'});
	&save_directive_struct($vconf, undef, $conf, $conf);
	&delete_file_if_empty($vconf->{'file'});
	}
foreach $file (keys %file_virts) {
	&lock_file($file);
	$deleted += &delete_virtuals_from_file($file, @{$file_virts{$file}});
	&unlock_file($file);
	}
&flush_file_lines();
&unlock_all_files();
&update_last_config_change();
&after_changing();
$deleted += scalar(@virts);
&webmin_log("virts", "delete", $deleted);
&redirect("");
