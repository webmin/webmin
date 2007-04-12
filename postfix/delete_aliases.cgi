#!/usr/local/bin/perl
# Delete several mail aliases

require './postfix-lib.pl';
require './aliases-lib.pl';
&ReadParse();
&error_setup($text{'adelete_err'});
$access{'aliases'} || &error($text{'aliases_ecannot'});
@afiles = &get_aliases_files(&get_current_value("alias_maps"));
&lock_alias_files(\@afiles);

# Find and validate
@d = split(/\0/, $in{'d'});
@d || &error($text{'adelete_enone'});
@aliases = &list_aliases(\@afiles);
foreach $d (@d) {
	($alias) = grep { $_->{'name'} eq $d } @aliases;
	if ($alias) {
		push(@delaliases, $alias);
		}
	}

# Delete the aliases
foreach $alias (@delaliases) {
	&delete_alias($alias, 1);
	}
&unlock_alias_files(\@afiles);

&regenerate_aliases();
&reload_postfix();

&webmin_log("delete", "aliases", scalar(@delaliases));
&redirect("aliases.cgi");

