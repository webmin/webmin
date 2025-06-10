#!/usr/local/bin/perl
# Delete several secrets

require './pptp-server-lib.pl';
&error_setup($text{'delete_err'});
$access{'secrets'} || &error($text{'secrets_ecannot'});
&ReadParse();
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Do the deletion
&lock_file($config{'pap_file'});
@seclist = &list_secrets();
foreach my $d (sort { $b <=> $a } @d) {
	$sec = $seclist[$d];
	&delete_secret($sec);
	}
&unlock_file($config{'pap_file'});
&webmin_log("deletes", undef, scalar(@d));
&redirect("list_secrets.cgi");



