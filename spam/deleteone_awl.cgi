#!/usr/local/bin/perl
# Delete all auto-whitelist entries

require './spam-lib.pl';
&error_setup($text{'dawl_err'});
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("awl");
&can_edit_awl($in{'user'}) || &error($text{'dawl_ecannot'});

# Delete them
&open_auto_whitelist_dbm($in{'user'}) || &error($text{'dawl_eopen'});
foreach $k (keys %awl) {
	delete($awl{$k});
	}
&close_auto_whitelist_dbm();
&redirect("edit_awl.cgi?search=".&urlize($in{'search'}).
	  "&user=".&urlize($in{'user'}).
	  "&file=".&urlize($in{'file'}).
	  "&title=".&urlize($in{'title'}));

