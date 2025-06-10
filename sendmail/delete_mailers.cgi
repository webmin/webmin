#!/usr/local/bin/perl
# Delete several mailers

require './sendmail-lib.pl';
require './mailers-lib.pl';
&ReadParse();
&error_setup($text{'mdelete_err'});
$conf = &get_sendmailcf();
$vfile = &mailers_file($conf);
($vdbm, $vdbmtype) = &mailers_dbm($conf);

# Find and validate
@d = split(/\0/, $in{'d'});
@d || &error($text{'adelete_enone'});
@virts = &list_mailers($vfile);
foreach $d (@d) {
	($virt) = grep { $_->{'domain'} eq $d } @virts;
	if ($virt) {
		push(@delvirts, $virt);
		}
	}

# Delete the aliases
&lock_file($vfile);
foreach $virt (@delvirts) {
	&delete_mailer($virt, $vfile, $vdbm, $vdbmtype);
	}
&unlock_file($vfile);

&webmin_log("delete", "mailers", scalar(@delvirts));
&redirect("list_mailers.cgi");

