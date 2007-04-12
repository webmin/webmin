#!/usr/local/bin/perl
# save_watch.cgi
# Update an existing watch group

require './mon-lib.pl';
&ReadParse();
$conf = &get_mon_config();
$watch = $conf->[$in{'idx'}];
if ($in{'delete'}) {
	&save_directive($conf, $watch, undef);
	}
else {
	$watch->{'values'} = [ $in{'group'} ];
	&save_directive($conf, $watch, $watch);
	}
&flush_file_lines();
&redirect("list_watches.cgi");

