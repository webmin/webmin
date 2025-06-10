#!/usr/local/bin/perl
# edit_admin.cgi
# A form for editing admin options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'admopts'} || &error($text{'eadm_ecannot'});
&ui_print_header(undef, $text{'eadm_header'}, "", "edit_admin", 0, 0, 0, &restart_button());
my $conf = &get_config();

print &ui_form_start("save_admin.cgi", "post");
print &ui_table_start($text{'eadm_aao'}, "width=100%", 4);

if ($squid_version < 2) {
	my $v = &find_config("cache_effective_user", $conf);
	print &ui_table_row($text{'eadm_runasuu'},
		&ui_radio("effective_def", $v ? 0 : 1,
			  [ [ 1, $text{'eadm_nochange'} ],
			    [ 0, $text{'eadm_user'}." ".
				 &unix_user_input("effective_u",
				     $v ? $v->{'values'}->[0] : "")." ".
				 $text{'eadm_group'}." ".
				 &unix_group_input("effective_g",
                                     $v ? $v->{'values'}->[1] : "") ] ]));
	}
else {
	print &opt_input($text{'eadm_runasuu'}, "cache_effective_user", $conf,
			 $text{'eadm_nochange'}, 8,
			 &user_chooser_button("cache_effective_user", 0));
	print &opt_input($text{'eadm_runasug'}, "cache_effective_group", $conf,
			 $text{'eadm_nochange'}, 8,
			 &group_chooser_button("cache_effective_group", 0));
	}

print &opt_input($text{'eadm_cmemail'}, "cache_mgr",
		 $conf, $text{'eadm_default'}, 35);

print &opt_input($text{'eadm_vhost'}, "visible_hostname",
		 $conf, $text{'eadm_auto'}, 35);

if ($squid_version < 2) {
	print &opt_input($text{'eadm_annto'}, "announce_to",
			 $conf, $text{'eadm_default'}, 40);

	print &opt_input($text{'eadm_every'}, "cache_announce", $conf,
			 $text{'eadm_never'}, 6, "hours");
	}
else {
	print &opt_input($text{'eadm_uniq'}, "unique_hostname",
			 $conf, $text{'eadm_auto'}, 35);

	if ($squid_version >= 2.4) {
		print &opt_input($text{'eadm_haliases'}, "hostname_aliases",
				 $conf, $text{'eadm_none'}, 35);
		}

	print &opt_input($text{'eadm_cah'}, "announce_host", $conf,
			 $text{'eadm_default'}, 20);
	print &opt_input($text{'eadm_cap'}, "announce_port", $conf,
			 $text{'eadm_default'}, 6);

	print &opt_input($text{'eadm_caf'}, "announce_file", $conf,
			 $text{'eadm_none'}, 35, &file_chooser_button("announce_file"));
	print &opt_time_input($text{'eadm_annp'}, "announce_period", $conf,
			      $text{'eadm_default'}, 4);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'eadm_buttsave'} ] ]);

&ui_print_footer("", $text{'eadm_return'});

