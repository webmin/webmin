#!/usr/local/bin/perl
# Delete several domains

require './sendmail-lib.pl';
require './domain-lib.pl';
&ReadParse();
&error_setup($text{'ddelete_err'});
$conf = &get_sendmailcf();
$vfile = &domains_file($conf);
($vdbm, $vdbmtype) = &domains_dbm($conf);

# Find and validate
@d = split(/\0/, $in{'d'});
@d || &error($text{'adelete_enone'});
@virts = &list_domains($vfile);
foreach $d (@d) {
	($virt) = grep { $_->{'from'} eq $d } @virts;
	if ($virt) {
		push(@delvirts, $virt);
		}
	}

# Delete the aliases
&lock_file($vfile);
foreach $virt (@delvirts) {
	&delete_domain($virt, $vfile, $vdbm, $vdbmtype);
	}
&unlock_file($vfile);

&webmin_log("delete", "domains", scalar(@delvirts));
&redirect("list_domains.cgi");

