#!/usr/local/bin/perl
# cron_editor.pl
# Called by crontab -e to edit an users cron table.. 

sleep(1);	# This is needed because the stupid crontab -e command
		# checks the mtime before and after editing, and if they are
		# the same it assumes no change has been made!!
open(SRC, "<".$ENV{"CRON_EDITOR_COPY"});
open(DST, ">".$ARGV[0]) || die "Failed to open $ARGV[0] : $!";
while(<SRC>) {
	if (!/^#.*DO NOT EDIT/i && !/^#.*installed on/i &&
	    !/^#.*Cron version/i) {
		(print DST $_) || die "Failed to write to $ARGV[0] : $!";
		}
	}
close(SRC);
close(DST) || die "Failed to write to $ARGV[0] : $!";
