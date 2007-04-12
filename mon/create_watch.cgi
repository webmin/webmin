#!/usr/local/bin/perl
# create_watch.cgi
# Add a new watch list for some group

require './mon-lib.pl';
&ReadParse();
$conf = &get_mon_config();

&save_directive($conf, undef, { 'name' => 'watch',
				'values' => [ $in{'group'} ] });
&flush_file_lines();
&redirect("list_watches.cgi");

