#!/usr/local/bin/perl
# Display the forgotten password form

BEGIN { push(@INC, "."); };
use WebminCore;
$no_acl_check++;
&init_config();
&ReadParse();
$gconfig{'forgot_pass'} || &error($text{'forgot_ecannot'});

&ui_print_header(undef, $text{'forgot_title'}, "", undef, undef, 1, 1);

print "<center>\n";
print $text{'forgot_desc'},"<p>\n";
print &ui_form_start("forgot_send.cgi", "post");
print "<b>$text{'forgot_user'}</b>\n",
      &ui_textbox("forgot", $in{'failed'}, 40),"<br>\n";
print &ui_form_end([ [ undef, $text{'forgot_ok'} ] ]);
print "</center>\n";

&ui_print_footer();

