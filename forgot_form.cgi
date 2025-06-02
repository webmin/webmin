#!/usr/local/bin/perl
# Display the forgotten password form

BEGIN { push(@INC, "."); };
use WebminCore;
$no_acl_check++;
$trust_unknown_referers = 1;
&init_config();
&ReadParse();
&load_theme_library();

&theme_forgot_handler($0) if (defined(&theme_forgot_handler));
&error_setup($text{'forgot_err'});
$gconfig{'forgot_pass'} || &error($text{'forgot_ecannot'});
$remote_user && &error($text{'forgot_elogin'});

&ui_print_header(undef, $text{'forgot_title'}, "", undef, undef, 1, 1);

print "<center>\n";
print $text{'forgot_desc'},"<p>\n";
print &ui_form_start("forgot_send.cgi", "post");
print "<b>$text{'forgot_user'}</b>\n",
      &ui_textbox("forgot", $in{'failed'}, 40),"<br>\n";
print &ui_form_end([ [ undef, $text{'forgot_go'} ] ]);
print "</center>\n";

&ui_print_footer();

