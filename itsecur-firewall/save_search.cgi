#!/usr/bin/perl
# Save the current search

require './itsecur-lib.pl';
&can_edit_error("report");
&ReadParse();

# Validate inputs
$in{'save_name'} =~ /\S/ && $in{'save_name'} !~ /\.\./ ||
	&error($text{'report_esave'});
%search = ( 'save_name', $in{'save_name'} );
foreach $f (@search_fields) {
	foreach $i (keys %in) {
		if ($i =~ /^\Q$f\E_/) {
			$search{$i} = $in{$i};
			}
		}
	}
&save_search(\%search);
&redirect("list_report.cgi?save_name=".&urlize($in{'save_name'}));

