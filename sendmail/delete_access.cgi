#!/usr/local/bin/perl
# Delete several spam control rules

require './sendmail-lib.pl';
require './access-lib.pl';
&ReadParse();
&error_setup($text{'sdelete_err'});
$conf = &get_sendmailcf();
$vfile = &access_file($conf);
($vdbm, $vdbmtype) = &access_dbm($conf);

# Find and validate
@d = split(/\0/, $in{'d'});
@d || &error($text{'adelete_enone'});
@virts = &list_access($vfile);
foreach $d (@d) {
	($virt) = grep { $_->{'from'} eq $d } @virts;
	&can_edit_access($virt) || &error(&text('sdelete_ecannot', $d));
	if ($virt) {
		push(@delvirts, $virt);
		}
	}

# Delete the rules
&lock_file($vfile);
foreach $virt (@delvirts) {
	&delete_access($virt, $vfile, $vdbm, $vdbmtype);
	}
&unlock_file($vfile);

&webmin_log("delete", "accesses", scalar(@delvirts));
&redirect("list_access.cgi");

