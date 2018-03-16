#!/usr/local/bin/perl

BEGIN { push(@INC, ".."); };
use WebminCore;

&init_config();
&ReadParse();

$msg="error_$in{'code'}";
&ui_print_header(undef, "$text{'error'} $in{'code'}: $text{$msg}", "", undef, undef, 1, 1);
print ui_alert_box("<br>$in{'message'}<p>$in{'body'}", "warn");

&ui_print_footer("/", $text{'error_previous'});

