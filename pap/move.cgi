#!/usr/local/bin/perl
# move.cgi
# Move a caller ID number up or down

require './pap-lib.pl';
$access{'dialin'} || &error($text{'dialin_ecannot'});
&ReadParse();
@dialin = &parse_dialin_config();

&lock_file($config{'dialin_config'});
if ($in{'up'}) {
	&swap_dialins($dialin[$in{'idx'}], $dialin[$in{'idx'}-1], \@dialin);
	}
else {
	&swap_dialins($dialin[$in{'idx'}], $dialin[$in{'idx'}+1], \@dialin);
	}
&unlock_file($config{'dialin_config'});
&webmin_log("move", "dialin", $dialin[$in{'idx'}]->{'number'},
			      $dialin[$in{'idx'}]);
&redirect("list_dialin.cgi");

