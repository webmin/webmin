#!/usr/local/bin/perl
# Show the Fetchmail configuration for one user

require './fetchmail-lib.pl';
&ReadParse();
&can_edit_user($in{'user'}) || &error($text{'poll_ecannot'});
@uinfo = getpwnam($in{'user'});
@uinfo || &error($text{'poll_eusername'});
$file = "$uinfo[7]/.fetchmailrc";
@conf = &parse_config_file("$uinfo[7]/.fetchmailrc");
@conf = grep { $_->{'poll'} } @conf;
&ui_print_header(&text('user_header', "<tt>$in{'user'}</tt>"), $text{'user_title'}, "");

print &show_polls(\@conf, $file, $in{'user'});

&ui_print_footer("", $text{'index_return'});

