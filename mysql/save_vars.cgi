#!/usr/local/bin/perl
# Either return to the list_vars.cgi page with new variables for editing,
# or save those that were edited

require './mysql-lib.pl';
$access{'perms'} == 1 || &error($text{'vars_ecannot'});
&ReadParse();
@d = split(/\0/, $in{'d'});
if ($in{'save'} || !@d) {
	# Update edited
	$count = 0;
	foreach $v (keys %in) {
		if ($v =~ /^value_(\S+)$/) {
			&execute_sql_logged($master_db,
					    "set global $1 = $in{$v}");
			$first ||= $1;
			$count++;
			}
		}
	&webmin_log("set", undef, $count);
	&redirect("list_vars.cgi?search=".&urlize($in{'search'})."#$first");
	}
else {
	# Return to list page, but in edit mode
	&redirect("list_vars.cgi?search=".&urlize($in{'search'})."&".
		join("&", map { "d=".&urlize($_) } @d).
		"#".$d[0]);
	}


