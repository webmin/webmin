#!/usr/local/bin/perl
# Delete multiple jails at once

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text, %config);
&ReadParse();
&error_setup($text{'jails_derr'});

# Get them and delete them
my @d = split(/\0/, $in{'d'});
@d || &error($text{'jails_enone'});
my @jails = &list_jails();
foreach my $name (@d) {
	my ($jail) = grep { $_->{'name'} eq $name } @jails;
	next if (!$jail);
	&lock_file($jail->{'file'});
	&delete_section($jail->{'file'}, $jail);
	&unlock_file($jail->{'file'});
	}

&webmin_log("delete", "jails", scalar(@d));
&redirect("list_jails.cgi");
