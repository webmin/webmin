#!/usr/local/bin/perl
# index.cgi
# Redirect to default index

require './proc-lib.pl';
if ($config{'default_mode'} ne "last") {
	$idx = "index_$config{'default_mode'}.cgi";
	}
elsif (open(INDEX, "<$index_file")) {
	chop($idx = <INDEX>);
	close(INDEX);
	if (!$idx) {
		$idx = "index_tree.cgi";
		}
	}
else {
	$idx = "index_tree.cgi";
	}
($idxfn = $idx) =~ s/\?.*$//;
if (!-r "$module_root_directory/$idxfn") {
	# Bogus index
	$idx = "index_tree.cgi";
	}
&redirect($idx);

