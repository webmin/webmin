#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# A form for controlling general parameters.
#
# << Here are all options seen in Postfix sample-misc.cf >>

require './postfix-lib.pl';


$access{'general'} || &error($text{'general_ecannot'});
&ui_print_header(undef, $text{'general_title'}, "", "general_opts");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

# Form start
print &ui_form_start("save_opts_misc.cgi", "post");
print &ui_table_start($text{'general_title_sensible'}, "width=100%", 4);

&option_radios_freefield("myorigin", 30, $text{'opts_myorigin_as_myhostname'},
			                 '$mydomain', $text{'opts_myorigin_as_mydomain'});

&option_radios_freefield("mydestination", 60, $text{'opts_mydestination_default'},
			                      '$myhostname, localhost.$mydomain, $mydomain', $text{'opts_mydestination_domainwide'});

$v = &if_default_value("notify_classes") ? "" :
	&get_current_value("notify_classes");
@v = split(/[, ]+/, $v);
print &ui_table_row(&hlink($text{'opts_notify_classes'},
		 	   'opt_notify_classes'),
		    &ui_radio("notify_classes_def",
			      $v ? "__USE_FREE_FIELD__"
				 : "__DEFAULT_VALUE_IE_NOT_IN_CONFIG_FILE__",
			      [ [ "__DEFAULT_VALUE_IE_NOT_IN_CONFIG_FILE__",
				  $text{'default'} ],
				[ "__USE_FREE_FIELD__",
				  $text{'opts_notify_classes_sel'} ] ]).
		    "<br>\n".
		    &ui_select("notify_classes", \@v,
		       [ [ "bounce", "bounce - Bounced mail" ],
			 [ "2bounce", "2bounce - Double-bounced mail" ],
			 [ "delay", "delay - Delayed mail" ],
			 [ "policy", "policy - Policy rejected clients" ],
			 [ "protocol", "protocol - Client protocol errors" ],
			 [ "resource", "resource - Resource problems" ],
		  	 [ "software", "software - Software problems" ] ],
		       7, 1, 1));

print &ui_table_end();
print &ui_table_start($text{'general_title_others'}, "width=100%", 4);

&option_radios_freefield("relayhost", 45, $text{'opts_direct'});

&option_radios_freefield("always_bcc", 40, $text{'opts_always_bcc_none'});

&option_freefield("daemon_timeout", 15);
&option_freefield("default_database_type", 15);

&option_freefield("default_transport", 15);
&option_freefield("double_bounce_sender", 15);

&option_freefield("hash_queue_depth", 15);
&option_freefield("hash_queue_names", 15);

&option_freefield("hopcount_limit", 15);
&option_radios_freefield("delay_warning_time", 15, $text{'opts_delay_warning_time_default2'});

&option_radios_freefield("inet_interfaces", 40, $text{'opts_all_interfaces'});

&option_freefield("ipc_idle", 15);
&option_freefield("ipc_timeout", 15);

&option_freefield("mail_name", 15);
&option_freefield("mail_owner", 15);

&option_freefield("mail_version", 25);

&option_freefield("max_idle", 15);
&option_freefield("max_use", 15);

&option_radios_freefield("myhostname", 40, $text{'opts_myhostname_default'});

&option_radios_freefield("mydomain", 40, $text{'opts_mydomain_default'});

&option_radios_freefield("mynetworks", 60, $text{'opts_mynetworks_default'});

&option_select("mynetworks_style",
	       [ [ "subnet", $text{'opts_mynetworks_subnet'} ],
		 [ "class", $text{'opts_mynetworks_class'} ],
		 [ "host", $text{'opts_mynetworks_host'} ] ]);

&option_radios_freefield("bounce_notice_recipient", 15, $default);
&option_radios_freefield("2bounce_notice_recipient", 15, $default);

&option_radios_freefield("delay_notice_recipient", 15, $default);
&option_radios_freefield("error_notice_recipient", 15, $default);

&option_freefield("queue_directory", 45);

&option_freefield("process_id_directory", 20);
&option_freefield("recipient_delimiter", 20);

if (&compare_version_numbers($postfix_version, 2.1) < 0) {
	&option_freefield("program_directory", 45);
	}

&option_radios_freefield("relocated_maps", 60, $text{'opts_relocated_maps_default'});

&option_yesno("sun_mailtool_compatibility", 'help');
&option_freefield("trigger_timeout", 15);

&option_radios_freefield("content_filter", 60, $text{'opts_content_filter_default'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

&ui_print_footer("", $text{'index_return'});
