#!/usr/local/bin/perl
# Delete several mail aliases

require './sendmail-lib.pl';
require './aliases-lib.pl';
&ReadParse();
&error_setup($text{'adelete_err'});
$access{'amode'} > 0 || &error($text{'asave_ecannot2'});
$conf = &get_sendmailcf();
$afile = &aliases_file($conf);

# Find and validate
@d = split(/\0/, $in{'d'});
@d || &error($text{'adelete_enone'});
@aliases = &list_aliases($afile);
foreach $d (@d) {
	($alias) = grep { $_->{'name'} eq $d } @aliases;
	if ($alias) {
		&can_edit_alias($alias) || &error(&text('adelete_ecannot', $d));
		push(@delaliases, $alias);
		}
	}

# Delete the aliases
&lock_alias_files($afile);
foreach $alias (@delaliases) {
	&delete_alias($alias);
	}
&unlock_alias_files($afile);

&webmin_log("delete", "aliases", scalar(@delaliases));
&redirect("list_aliases.cgi");

