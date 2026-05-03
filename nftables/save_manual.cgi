#!/usr/bin/perl
# save_manual.cgi
# Save the manually edited nftables rules file

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
my $err = validate_nftables_text($in{'data'});
error(text('manual_evalidate', $err)) if ($err);

open_lock_tempfile(my $fh, ">$file");
print_tempfile($fh, $in{'data'});
close_tempfile($fh);

my @tables = get_nftables_save($file);
sync_managed_metadata(@tables);
update_last_config_change();

webmin_log("manual", undef, $file);
redirect("");
