#!/usr/local/bin/perl
# edit_allow.cgi
# A form for editing the system cron.allow and cron.deny files

require './cron-lib.pl';
$access{'allow'} || &error($text{'allow_ecannot'});
&ui_print_header(undef, $text{'allow_title'}, "");

print &ui_form_start("save_allow.cgi");
print "$text{'allow_desc'} <p>\n";

$allowfile = (-r $config{cron_allow_file});
$denyfile = (-r $config{cron_deny_file});
$nofile = $config{cron_deny_all};
$mode = !$allowfile && !$denyfile ? 0 :
	$allowfile ? 1 : 2;
print &ui_radio_table("mode", $mode,
	[ [ 0, $nofile==0 ? $text{'allow_all1'} :
	       $nofile==1 ? $text{'allow_all2'} :
			    $text{'allow_all3'} ],
	  [ 1, $text{'allow_allow'},
		&ui_textbox("allow",
		  $allowfile ? join(' ', &list_allowed()) : "", 50).
		" ".&user_chooser_button("allow", 1) ],
	  [ 2, $text{'allow_deny'},
		&ui_textbox("deny",
		  $denyfile ? join(' ', &list_denied()) : "", 50).
		" ".&user_chooser_button("deny", 1) ] ]);
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

