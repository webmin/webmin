#!/usr/local/bin/perl
# Show binary logging status, configuration options and log cleanup

require './mysql-lib.pl';
$access{'perms'} == 1 || &error($text{'binlogs_ecannot'});
&ReadParse();
&ui_print_header(undef, $text{'binlogs_title'}, "", "binlogs");

# Make sure config exists
$conf = &get_mysql_config();
if (!$conf) {
	print &text('cnf_efile', "<tt>$config{'my_cnf'}</tt>",
		    "../config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
$mysqld = &get_mysqld_config_section($conf);
$mysqld || &error($text{'cnf_emysqld'});
$mems = $mysqld->{'members'};
$local = &is_mysql_local();

# Get the status reported by the running server
($curfile, $curpos) = &get_binary_log_status();
@logs = &list_binary_logs();
$liveformat = eval {
	local $main::error_must_die = 1;
	my $d = &execute_sql($master_db,
		"show variables like 'binlog_format'");
	@{$d->{'data'}} ? $d->{'data'}->[0]->[1] : undef;
	};

# Show tabs for configuration and log cleanup
@tabs = ( [ 'options', $text{'binlogs_tab_options'} ],
	  $curfile ? ( [ 'purge', $text{'binlogs_tab_purge'} ] ) : ( ) );
%valid = map { $_->[0] => 1 } @tabs;
$mode = $in{'mode'} && $valid{$in{'mode'}} ? $in{'mode'} : 'options';
print &ui_tabs_start(\@tabs, "mode", $mode, 1);

# Configuration tab
print &ui_tabs_start_tab("mode", "options");
print &ui_div($text{'binlogs_desc_options'});
print &ui_form_start("save_binlogs.cgi", "post");
print &ui_table_start($text{'binlogs_header'}, "width=100%", 2);

# Current state, as one read-only row
if ($curfile) {
	$total = 0;
	foreach $l (@logs) {
		$total += $l->{'size'};
		}
	print &ui_table_row($text{'binlogs_active'},
		&text('binlogs_activeyes', "<tt>".&html_escape($curfile)."</tt>",
		      $curpos, scalar(@logs), &nice_size($total)).
		($liveformat ? " ".&text('binlogs_activefmt',
					 uc($liveformat)) : ""));
	}
else {
	print &ui_table_row($text{'binlogs_active'}, $text{'no'});
	}

if ($local) {
	# Enabled state considers both positive and negative directives, the
	# live server status, and finally whether this server version logs
	# by default when nothing is configured (as MySQL 8+ does)
	$lbdir = &find("log_bin", $mems) || &find("log-bin", $mems);
	$skipdir = &find("skip-log-bin", $mems) ||
		   &find("skip_log_bin", $mems) ||
		   &find("disable-log-bin", $mems) ||
		   &find("disable_log_bin", $mems);
	$lb = $lbdir ? $lbdir->{'value'} : undef;
	$enabled = $skipdir ? 0 : $lbdir ? 1 : $curfile ? 1 :
		   &get_binlog_default_on();
	print &ui_table_row(&hlink($text{'binlogs_enabled'},
				   "binlogs_enabled"),
		&ui_yesno_radio("enabled", $enabled));

	print &ui_table_row(&hlink($text{'binlogs_base'}, "binlogs_base"),
		&ui_opt_textbox("base", $lb, 30, $text{'binlogs_base_def'}));

	$sid = &find_value("server_id", $mems);
	$sid = &find_value("server-id", $mems) if (!defined($sid));
	print &ui_table_row(&hlink($text{'binlogs_serverid'},
				   "binlogs_serverid"),
		&ui_opt_textbox("serverid", $sid, 10, $text{'default'}));

	# Log format, which must be ROW for point-in-time recovery
	$fmt = &find_value("binlog_format", $mems);
	$fmt = &find_value("binlog-format", $mems) if (!defined($fmt));
	print &ui_table_row(&hlink($text{'binlogs_format'},
				   "binlogs_format"),
		&ui_select("format", uc($fmt // ''),
			   [ [ '', $text{'default'} ],
			     [ 'ROW', $text{'binlogs_format_row'} ],
			     [ 'MIXED', $text{'binlogs_format_mixed'} ],
			     [ 'STATEMENT',
			       $text{'binlogs_format_statement'} ] ]));

	# Maximum size of one log file before rotation
	$maxsize = &find_value("max_binlog_size", $mems);
	$maxsize = &find_value("max-binlog-size", $mems)
		if (!defined($maxsize));
	print &ui_table_row(&hlink($text{'binlogs_maxsize'},
				   "binlogs_maxsize"),
		&ui_radio("maxsize_def", defined($maxsize) ? 0 : 1,
			  [ [ 1, $text{'default'} ], [ 0, " " ] ])."\n".
		&mysql_size_input("maxsize", $maxsize));

	# Retention period, stored in a variant-specific variable
	($ver, $variant) = &get_mysql_variant_cached();
	$secs = &find_value("binlog_expire_logs_seconds", $mems);
	$days = &find_value("expire_logs_days", $mems);
	$expire = defined($secs) ? &format_binlog_expire_days($secs) :
		  defined($days) ? $days : undef;
	print &ui_table_row(&hlink($text{'binlogs_expire'},
				   "binlogs_expire"),
		&ui_opt_textbox("expire", $expire, 6,
				$text{'binlogs_expire_def'}).
		" ".$text{'binlogs_days'});

	print &ui_table_end();
	print &ui_form_end([ [ "save", $text{'save'} ],
			     &is_mysql_running() > 0 ?
				( [ "restart",
				    $text{'binlogs_restart'} ] ) : ( ) ]);
	}
else {
	# Config file editing only works for a local database server
	print &ui_table_end();
	print &ui_form_end();
	print &ui_alert($text{'binlogs_eremote'}, 'info');
	}
print &ui_tabs_end_tab("mode", "options");

# Log cleanup tab
if ($curfile) {
	print &ui_tabs_start_tab("mode", "purge");
	print &ui_div($text{'binlogs_desc_purge'});
	print &ui_form_start("purge_binlogs.cgi", "post");
	print &ui_table_start($text{'binlogs_purgeheader'},
			      "width=100%", 2);
	print &ui_table_row(&hlink($text{'binlogs_purge'},
				   "binlogs_purge"),
		&ui_radio("mode", 0,
		  [ [ 0, &text('binlogs_purgedays',
			       &ui_textbox("days", 7, 6))."<br>" ],
		    [ 1, $text{'binlogs_purgeall'} ] ]));
	print &ui_table_end();
	print &ui_form_end([ [ "purge", $text{'binlogs_purgeok'} ] ]);
	print &ui_tabs_end_tab("mode", "purge");
	}

print &ui_tabs_end();

# Button to close the current log and start a new one, which gives backups
# and log deletion a clean boundary to work with
if ($curfile) {
	print &ui_hr();
	print &ui_buttons_start();
	print &ui_buttons_row("flush_binlogs.cgi", $text{'binlogs_rotateok'},
		&text('binlogs_rotatedesc',
		      "<tt>".&html_escape($curfile)."</tt>"));
	print &ui_buttons_end();
	}

&ui_print_footer("", $text{'index_return'});
