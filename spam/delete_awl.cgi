#!/usr/local/bin/perl
# Delete auto-whitelist entries

require './spam-lib.pl';
&error_setup($text{'dawl_err'});
&can_use_check("awl");
&ReadParse();

# Check stuff
&open_auto_whitelist_dbm($in{'user'}) || &error($text{'dawl_eopen'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'dawl_enone'});

# Delete from hash
foreach $d (@d) {
	delete($awl{$d});
	delete($awl{$d."|totscore"});
	}

&close_auto_whitelist_dbm();
&redirect("edit_awl.cgi?search=".&urlize($in{'search'}).
	  "&user=".&urlize($in{'user'}));

