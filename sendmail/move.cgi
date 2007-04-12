#!/usr/local/bin/perl
# move.cgi
# Move a feature up or down

require './sendmail-lib.pl';
require './features-lib.pl';
&ReadParse();
$features_access || &error($text{'features_ecannot'});
@features = &list_features();

&lock_file($config{'sendmail_mc'});
if ($in{'up'}) {
	&swap_features($features[$in{'idx'}-1], $features[$in{'idx'}]);
	}
elsif ($in{'down'}) {
	&swap_features($features[$in{'idx'}], $features[$in{'idx'}+1]);
	}
&unlock_file($config{'sendmail_mc'});
&webmin_log("move", "feature", undef, $features[$in{'idx'}]);

&redirect("list_features.cgi");

