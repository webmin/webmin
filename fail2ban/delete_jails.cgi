#!/usr/local/bin/perl
# Delete multiple jails at once

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%in, %text, %config);
&ReadParse();
&error_setup($text{'jails_derr'});

# Get them and delete them
my @d = split(/\0/, $in{'d'});
@d || &error($text{'jails_enone'});
my @jails = &list_jails();
&lock_all_config_files();
foreach my $name (@d) {
	my ($jail) = grep { $_->{'name'} eq $name } @jails;
	next if (!$jail);
	&delete_section($jail->{'file'}, $jail);
	}
&unlock_all_config_files();

&webmin_log("delete", "jails", scalar(@d));
&redirect("list_jails.cgi");
