#!/usr/bin/perl
# save_manual.cgi
# Save a manually edited nftables configuration file

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParseMime();
error_setup($text{'manual_err'});
assert_manual_acl();

my @files = unique(get_nftables_config_files());
@files || error($text{'manual_enofile'});
my $file = $in{'file'};
indexof($file, @files) >= 0 || error($text{'manual_efile'});

$in{'data'} =~ s/\r//g;

# Check the saved ruleset as a whole with the new content in place, as an
# included file on its own may use a define from the file that includes it.
# Put the old content back if nft rejects the result
my $old = -r $file ? read_file_contents($file) : undef;
open_lock_tempfile(my $fh, ">$file");
print_tempfile($fh, $in{'data'});
close_tempfile($fh);

my $err = validate_nftables_files();
if ($err) {
	if (defined($old)) {
		open_lock_tempfile(my $rfh, ">$file");
		print_tempfile($rfh, $old);
		close_tempfile($rfh);
		}
	else {
		unlink_file($file);
		}
	error(text('manual_evalidate', $err));
	}

update_last_config_change();

webmin_log("manual", undef, $file);
redirect("");
