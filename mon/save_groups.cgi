#!/usr/local/bin/perl
# save_groups.cgi
# Save all hostgroup directives

require './mon-lib.pl';
&ReadParse();
&error_setup($text{'groups_err'});
$conf = &get_mon_config();
@ogroups = &find("hostgroup", $conf);

for($i=0; defined($in{"group_$i"}); $i++) {
	next if (!$in{"group_$i"});
	$in{"group_$i"} =~ /^\S+$/ || &error($text{'groups_egroup'});
	@mems = split(/\s+/, $in{"members_$i"});
	@mems || &error($text{'groups_emembers'});
	push(@groups, { 'name' => 'hostgroup',
			'values' => [ $in{"group_$i"}, @mems ] });
	}

for($i=0; $i<@ogroups || $i<@groups; $i++) {
	&save_directive($conf, $ogroups[$i], $groups[$i]);
	}
&flush_file_lines();

&redirect("");

