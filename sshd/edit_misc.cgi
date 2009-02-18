#!/usr/local/bin/perl
# edit_misc.cgi
# Display all other SSHd options

require './sshd-lib.pl';
&ui_print_header(undef, $text{'misc_title'}, "", "misc");
$conf = &get_sshd_config();

print &ui_form_start("save_misc.cgi");
print &ui_table_start($text{'misc_header'}, "width=100%", 2);

# X11 port forwarding
$x11 = &find_value("X11Forwarding", $conf);
print &ui_table_row($text{'misc_x11'},
	&ui_yesno_radio("x11", lc($x11) eq 'no' ? 0 :
			       lc($x11) eq 'yes' ? 1 :
			       $version{'type'} eq 'ssh' ? 1 : 0));

if ($version{'type'} ne 'ssh' || $version{'number'} < 2) {
	# X display offset
	$xoff = &find_value("X11DisplayOffset", $conf);
	print &ui_table_row($text{'misc_xoff'},
		&ui_opt_textbox("xoff", $xoff, 6, $text{'default'}));

	if ($version{'type'} eq 'ssh' || $version{'number'} >= 2) {
		# Path to xauth
		$xauth = &find_value("XAuthLocation", $conf);
		print &ui_table_row($text{'misc_xauth'},
			&ui_opt_textbox("xauth", $xauth, 60, $text{'default'}).
			" ".&file_chooser_button("xauth"));
		}
	}

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	# Default umask
	$umask = &find_value("Umask", $conf);
	print &ui_table_row($text{'misc_umask'},
		&ui_opt_textbox("umask", $umask, 4, $text{'misc_umask_def'}));
	}

# Syslog facility
$syslog = &find_value("SyslogFacility", $conf);
print &ui_table_row($text{'misc_syslog'},
	&ui_radio("syslog_def", $syslog ? 0 : 1,
		  [ [ 1, $text{'default'} ],
		    [ 0, &ui_select("syslog", uc($syslog),
				[ &list_syslog_facilities() ], 1, 0,
				$syslog ? 1 : 0) ] ]));

if ($version{'type'} eq 'openssh') {
	# Logging level
	$loglevel = &find_value("LogLevel", $conf);
	print &ui_table_row($text{'misc_loglevel'},
		&ui_radio("loglevel_def", $loglevel ? 0 : 1,
			[ [ 1, $text{'default'} ],
			  [ 0, &ui_select("loglevel", uc($loglevel),
				[ &list_logging_levels() ], 1, 0,
				$loglevel ? 1 : 0) ] ]));
	}

if ($version{'type'} ne 'ssh' || $version{'number'} < 2) {
	# Bits in key
	$bits = &find_value("ServerKeyBits", $conf);
	print &ui_table_row($text{'misc_bits'},
		&ui_opt_textbox("bits", $bits, 4, $text{'default'})." ".
		$text{'bits'});
	}

if ($version{'type'} eq 'ssh') {
	# Quite mode
	$quiet = &find_value("QuietMode", $conf);
	print &ui_table_row($text{'misc_quiet'},
		&ui_yesno_radio("quiet", lc($quiet) ne 'no'));
	}

if ($version{'type'} ne 'ssh' || $version{'number'} < 2) {
	# Interval between key re-generation
	$regen = &find_value("KeyRegenerationInterval", $conf);
	print &ui_table_row($text{'misc_regen'},
		&ui_opt_textbox("regen", $regen, 6, $text{'misc_regen_def'}).
		" ".$text{'secs'});
	}

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	# Detailed logging
	$fascist = &find_value("FascistLogging", $conf);
	print &ui_table_row($text{'misc_fascist'},
		&ui_yesno_radio("fascist", lc($fascist) eq 'yes'));
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 2) {
	# PID file
	$pid = &find_value("PidFile", $conf);
	print &ui_table_row($text{'misc_pid'},
		&ui_opt_textbox("pid", $pid, 60, $text{'default'}));
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 3.2) {
	# Use separate users
	$separ = &find_value("UsePrivilegeSeparation", $conf);
	print &ui_table_row($text{'misc_separ'},
		&ui_yesno_radio("separ", lc($separ) ne 'no'));
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

