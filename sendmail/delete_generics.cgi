#!/usr/local/bin/perl
# Delete several generics

require './sendmail-lib.pl';
require './generics-lib.pl';
&ReadParse();
&error_setup($text{'gdelete_err'});
$conf = &get_sendmailcf();
$vfile = &generics_file($conf);
($vdbm, $vdbmtype) = &generics_dbm($conf);

# Find and validate
@d = split(/\0/, $in{'d'});
@d || &error($text{'adelete_enone'});
@virts = &list_generics($vfile);
foreach $d (@d) {
	($virt) = grep { $_->{'from'} eq $d } @virts;
	if ($virt) {
		&can_edit_generic($virt) ||
			&error(&text('gdelete_ecannot', $d));
		push(@delvirts, $virt);
		}
	}

# Delete the aliases
&lock_file($vfile);
foreach $virt (@delvirts) {
	&delete_generic($virt, $vfile, $vdbm, $vdbmtype);
	}
&unlock_file($vfile);

&webmin_log("delete", "generics", scalar(@delvirts));
&redirect("list_generics.cgi");

