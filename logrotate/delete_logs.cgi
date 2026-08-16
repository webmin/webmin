#!/usr/local/bin/perl
# Delete a bunch of logrotate sections

require './logrotate-lib.pl';
&ReadParse();

# Validate inputs
&error_setup($text{'delete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Delete the sections
$parent = &get_config_parent();
$conf = $parent->{'members'};

# Copy each selected vendor file to the local override tree before changing
# it.  Reload the parsed configuration after copying so all line references
# point at the writable files.
%vendor_files = map { $conf->[$_]->{'file'}, 1 }
		grep { &is_vendor_config_file($conf->[$_]->{'file'}) } @d;
if (%vendor_files) {
	foreach $f (keys %vendor_files) {
		&ensure_local_config_override($f);
		}
	$parent = &get_config_parent();
	$conf = $parent->{'members'};
	}
foreach $d (sort { $b <=> $a } @d) {
	$log = $conf->[$d];
	&lock_file($log->{'file'});
	&save_directive($parent, $log, undef);
	push(@files, $log->{'file'});
	}
&flush_file_lines();

# Write out config
foreach $f (&unique(@files)) {
	&delete_if_empty($f);
	&unlock_file($f);
	}

&webmin_log("delete", "logs", scalar(@d));
&redirect("");

