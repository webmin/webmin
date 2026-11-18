#!/usr/local/bin/perl
# rmulti.pl
# Called when a tape change is needed for a multi-file restore. Links the
# base filename to the next one in the ordered sequence of multi-files

$no_acl_check++;
delete($ENV{'SCRIPT_NAME'});	# force use of $0 to determine module
delete($ENV{'FOREIGN_MODULE_NAME'});
require './fsdump-lib.pl';

$ARGV[0] =~ /^(.*)\/([^\/]+)$/ || die "Missing filename";
$dir = $1;
$file = $2;

# Find out where we are up to
$lnk = readlink($ARGV[0]);
if ($lnk =~ /^\Q$file\E\.(\d+)$/ && -r "$dir/$lnk" && !$ARGV[1]) {
	# Going to next file
	$nxt = "$file.".($1 + 1);
	}
else {
	# First file
	-r $ARGV[0] && !-l $ARGV[0] &&
		die "$ARGV[0] is not a link to the current archive!";
	$nxt = "$file.1";
	}

# Update the link
if (defined($ENV{'FSDUMP_RESTORE_DIRS'}) &&
    $ENV{'FSDUMP_RESTORE_DIRS'} ne '*') {
	# Check the directory containing the link and the volume it will open.
	local $access{'dirs'} = $ENV{'FSDUMP_RESTORE_DIRS'};
	&can_edit_dir($dir || "/") && &can_edit_dir("$dir/$nxt") ||
		die "$text{'restore_ecannot'}\n";
	}
unlink($ARGV[0]);
symlink($nxt, $ARGV[0]) || die "Failed to select the next archive: $!";
exit(0);

