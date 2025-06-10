#!/usr/local/bin/perl
# edit_progs.cgi
# A form for editing helper program options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'hprogs'} || &error($text{'eprogs_ecannot'});
&ui_print_header(undef, $text{'eprogs_header'}, "", "edit_progs", 0, 0, 0, &restart_button());
my $conf = &get_config();

print &ui_form_start("save_progs.cgi", "post");
print &ui_table_start($text{'eprogs_chpo'}, "width=100%", 4);

if ($squid_version < 2) {
	print &opt_input($text{'eprogs_sfp'}, "ftpget_program", $conf,
			 $text{'default'}, 40, &file_chooser_button("ftpget_program"));
	print &opt_input($text{'eprogs_fo'}, "ftpget_options", $conf, $text{'default'}, 15);
	}
else {
	print &opt_input($text{'eprogs_fcv'}, "ftp_list_width", $conf,
			 $text{'default'}, 6, $text{'eprogs_c'});
	}
print &opt_input($text{'eprogs_afl'}, "ftp_user", $conf, $text{'default'}, 15);

print &opt_input($text{'eprogs_sdp'}, "cache_dns_program", $conf, $text{'default'}, 40,
		 &file_chooser_button("cache_dns_program"));

print &opt_input($text{'eprogs_nodp'}, "dns_children", $conf, $text{'default'}, 5);
print &choice_input($text{'eprogs_adtr'}, "dns_defnames", $conf, "off",
		    $text{'yes'}, "on", $text{'no'}, "off");

if ($squid_version >= 2) {
	print &opt_input($text{'eprogs_dsa'}, "dns_nameservers", $conf,
			 $text{'eprogs_fr'}, 35);
	}

print &opt_input($text{'eprogs_ccp'}, "unlinkd_program", $conf,
		 $text{'default'}, 40, &file_chooser_button("unlinkd_program"));

print &opt_input($text{'eprogs_spp'}, "pinger_program", $conf,
		 $text{'default'}, 40, &file_chooser_button("pinger_program"));

print &choice_input($text{'eprogs_sppe'}, "pinger_enable", $conf, "on",
		    $text{'yes'}, "on", $text{'no'}, "off");

if ($squid_version >= 2.6) {
	print &ui_table_hr();

        print &opt_input($text{'eprogs_crp'}, "url_rewrite_program", $conf,
                         $text{'none'}, 40, &file_chooser_button("url_rewrite_program"));

	# Number of child processes for re-writes
	my $v = &find_config("url_rewrite_children", $conf);
	my @w = $v ? @{$v->{'values'}} : ();
	print &ui_table_row($text{'eprogs_norp'},
		&ui_opt_textbox("url_rewrite_children", $w[0], 6, $text{'default'}));

	# Child process options
	shift(@w);
	my %opts = map { split(/=/, $_, 2) } @w;
	print &ui_table_row($text{'eprogs_startup'},
		&ui_opt_textbox("url_rewrite_startup", $opts{'startup'}, 6,
				$text{'default'}));
	print &ui_table_row($text{'eprogs_idle'},
		&ui_opt_textbox("url_rewrite_idle", $opts{'idle'}, 6,
				$text{'default'}));
	print &ui_table_row($text{'eprogs_concurrency'},
		&ui_opt_textbox("url_rewrite_concurrency", $opts{'concurrency'}, 6,
				$text{'default'}));
	}
else {
	print &opt_input($text{'eprogs_crp'}, "redirect_program", $conf,
			 $text{'none'}, 40, &file_chooser_button("redirect_program"));
	print &opt_input($text{'eprogs_norp'}, "redirect_children", $conf,
			 $text{'default'}, 6);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'buttsave'} ] ]);

&ui_print_footer("", $text{'eprogs_return'});

