#!/usr/local/bin/perl
# Delete several SSL tunnels

require './stunnel-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Do the deletions
@stunnels = &list_stunnels();
foreach $d (sort { $b <=> $a } @d) {
	$st = $stunnels[$d];
	&lock_file($st->{'file'});
	if (&get_stunnel_version(\$dummy) >= 4) {
		if ($st->{'args'} =~ /^(\S+)\s+(\S+)/) {
			$cfile = $2;
			if ($cfile =~ /^\Q$module_config_directory\E\//) {
				&lock_file($cfile);
				unlink($cfile);
				}
			}
		}
	&delete_stunnel($st);
	}

&unlock_all_files();
&webmin_log("delete", "stunnels", scalar(@d));
&redirect("");

