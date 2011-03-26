#!/usr/bin/perl
# Enable, disable, log, un-log or delete a bunch of rules

require './itsecur-lib.pl';
&can_edit_error("rules");
&ReadParse();
@rules = &list_rules();
@nums = split(/\0/, $in{'r'});

&lock_itsecur_files();
foreach $n (@nums) {
	($r) = grep { $_->{'index'} == $n } @rules;
	if ($in{'enable'}) {
		$r->{'enabled'} = 1;
		}
	elsif ($in{'disable'}) {
		$r->{'enabled'} = 0;
		}
	elsif ($in{'logon'}) {
		$r->{'log'} = 1;
		}
	elsif ($in{'logoff'}) {
		$r->{'log'} = 0;
		}
	elsif ($in{'delete'}) {
		@rules = grep { $_ ne $r } @rules;
		}
	}

&automatic_backup();
&save_rules(@rules);
&unlock_itsecur_files();
&remote_webmin_log($in{'enable'} ? "enable" :
		   $in{'disable'} ? "disable" :
		   $in{'logon'} ? "logon" :
		   $in{'logoff'} ? "logoff" : "delete", "rules", undef,
		   { 'count' => scalar(@nums) } );
&redirect("list_rules.cgi");

