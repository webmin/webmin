#!/usr/local/bin/perl
# save_check.cgi
# Save the list of search types that are allowed for searches made
# from help_search_link()

require './man-lib.pl';
&ReadParse();
&lock_file("$module_config_directory/config");
@check = split(/\0/, $in{'check'});
if (!@check) {
	$config{'check'} = 'NONE';
	}
elsif (@check == $in{'count'}) {
	$config{'check'} = '';
	}
else {
	$config{'check'} = join(" ", @check);
	}
&write_file("$module_config_directory/config", \%config);
&unlock_file("$module_config_directory/config");
&redirect("");

