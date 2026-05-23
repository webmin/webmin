#!/usr/local/bin/perl
# Delete several mail aliases

require './postfix-lib.pl';    ## no critic
use strict;
use warnings;
our ($alias, $err, %access, @afiles, @aliases, @d, @delaliases, %in, %text);
require './aliases-lib.pl';    ## no critic
&ReadParse();
&error_setup($text{'adelete_err'});
$access{'aliases'} || &error($text{'aliases_ecannot'});
@afiles = &get_aliases_files(&get_current_value("alias_maps"));
&lock_alias_files(\@afiles);

# Find and validate
@d = split(/\0/, $in{'d'});
@d || &error($text{'adelete_enone'});
@aliases = &list_postfix_aliases();
foreach my $d (@d) {
	($alias) = grep { $_->{'name'} eq $d } @aliases;
	if ($alias) {
		push(@delaliases, $alias);
		}
	}

# Delete the aliases
foreach my $alias (@delaliases) {
	&delete_postfix_alias($alias);
	}
&unlock_alias_files(\@afiles);

&regenerate_aliases();
$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("delete", "aliases", scalar(@delaliases));
&redirect("aliases.cgi");

