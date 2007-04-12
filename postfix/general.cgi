#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Copyright (c) 2000 by Mandrakesoft
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#
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

print "<form action=save_opts_misc.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'general_title_sensible'}</b> <font size=\"-1\">".&hlink("$text{'what_is_it'}", "general_opts")."</font></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
&option_radios_freefield("myorigin", 30, $text{'opts_myorigin_as_myhostname'},
			                 '$mydomain', $text{'opts_myorigin_as_mydomain'});
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("mydestination", 60, $text{'opts_mydestination_default'},
			                      '$myhostname, localhost.$mydomain, $mydomain', $text{'opts_mydestination_domainwide'});
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("notify_classes", 40, $default);
print "</tr>\n";

print "</table></td></tr>\n";
print "<tr $tb><td><b>$text{'general_title_others'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
&option_radios_freefield("relayhost", 45, $text{'opts_direct'});
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("always_bcc", 40, $text{'opts_always_bcc_none'});
print "</tr>\n";

print "<tr>\n";
&option_freefield("daemon_timeout", 15);
&option_freefield("default_database_type", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("default_transport", 15);
&option_freefield("double_bounce_sender", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("hash_queue_depth", 15);
&option_freefield("hash_queue_names", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("hopcount_limit", 15);
&option_radios_freefield("delay_warning_time", 15, $text{'opts_delay_warning_time_default'});
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("inet_interfaces", 40, $text{'opts_all_interfaces'});
print "</tr>\n";

print "<tr>\n";
&option_freefield("ipc_idle", 15);
&option_freefield("ipc_timeout", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("mail_name", 15);
&option_freefield("mail_owner", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("mail_version", 25);
print "</tr>\n";

print "<tr>\n";
&option_freefield("max_idle", 15);
&option_freefield("max_use", 15);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("myhostname", 40, $text{'opts_myhostname_default'});
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("mydomain", 40, $text{'opts_mydomain_default'});
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("mynetworks", 60, $text{'opts_mynetworks_default'});
print "</tr>\n";

print "<tr>\n";
&option_select("mynetworks_style",
	       [ [ "", $text{'default'} ],
		 [ "subnet", $text{'opts_mynetworks_subnet'} ],
		 [ "class", $text{'opts_mynetworks_class'} ],
		 [ "host", $text{'opts_mynetworks_host'} ] ]);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("bounce_notice_recipient", 15, $default);
&option_radios_freefield("2bounce_notice_recipient", 15, $default);
print "<tr>\n";

print "</tr>\n";
&option_radios_freefield("delay_notice_recipient", 15, $default);
&option_radios_freefield("error_notice_recipient", 15, $default);
print "</tr>\n";

print "<tr>\n";
&option_freefield("queue_directory", 45);
print "</tr>\n";

print "<tr>\n";
&option_freefield("process_id_directory", 20);
&option_freefield("recipient_delimiter", 20);
print "</tr>\n";

if ($postfix_version < 2.1) {
	print "<tr>\n";
	&option_freefield("program_directory", 45);
	print "</tr>\n";
	}

print "<tr>\n";
&option_radios_freefield("relocated_maps", 60, $text{'opts_relocated_maps_default'});
print "</tr>\n";

print "<tr>\n";
&option_yesno("sun_mailtool_compatibility", 'help');
&option_freefield("trigger_timeout", 15);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("content_filter", 60, $text{'opts_content_filter_default'});
print "</tr>\n";

print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});
