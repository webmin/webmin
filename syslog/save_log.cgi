#!/usr/local/bin/perl
# save_log.cgi
# Save, create, delete or view a log

require './syslog-lib.pl';
&ReadParse();
&foreign_require("proc", "proc-lib.pl");
$conf = &get_config();

if ($in{'delete'}) {
	# Deleting a log 
	$access{'noedit'} && &error($text{'edit_ecannot'});
	$access{'syslog'} || &error($text{'edit_ecannot'});
	$log = $conf->[$in{'idx'}];
	&lock_file($log->{'cfile'});
	&can_edit_log($log) || &error($text{'save_ecannot1'});
	&delete_log($log);
	&unlock_file($log->{'cfile'});
	&redirect("");
	}
elsif ($in{'view'}) {
	# Viewing a log file
	if ($in{'idx'} ne '') {
		# From syslog
		$log = $conf->[$in{'idx'}];
		&can_edit_log($log) && $access{'syslog'} ||
			&error($text{'save_ecannot2'});
		$file = $log->{'file'};
		}
	elsif ($in{'oidx'} ne '') {
		# From another module
		@others = &get_other_module_logs($in{'omod'});
		($other) = grep { $_->{'mindex'} == $in{'oidx'} } @others;
		&can_edit_log($other) && $access{'others'} ||
			&error($text{'save_ecannot2'});
		if ($other->{'file'}) {
			$file = $other->{'file'};
			}
		else {
			$cmd = $other->{'cmd'};
			}
		}
	elsif ($in{'extra'}) {
		# Extra log file
		@extras = &extra_log_files();
		($extra) = grep { $_->{'file'} eq $in{'extra'} } @extras;
		$extra || &error($text{'save_ecannot7'});
		&can_edit_log($extra) || &error($text{'save_ecannot2'});
		$file = $extra->{'file'};
		}
	elsif ($in{'file'}) {
		# Explicitly named file
		$access{'any'} || &error($text{'save_ecannot6'});
		$file = $in{'file'};
		&can_edit_log($file) || &error($text{'save_ecannot2'});
		}
	else {
		&error($text{'save_emissing'});
		}
	print "Refresh: $config{'refresh'}\r\n"
		if ($config{'refresh'});
	&ui_print_header("<tt>".&html_escape($file || $cmd)."</tt>",
			 $text{'view_title'}, "");

	$lines = $in{'lines'} ? int($in{'lines'}) : $config{'lines'};
	$filter = $in{'filter'} ? quotemeta($in{'filter'}) : "";

	&filter_form();

	$| = 1;
	print "<pre>";
	local $tailcmd = $config{'tail_cmd'} || "tail -n LINES";
	$tailcmd =~ s/LINES/$lines/g;
	if ($filter ne "") {
		# Are we supposed to filter anything? Then use grep.
		local @cats;
		if ($cmd) {
			# Getting output from a command
			push(@cats, $cmd);
			}
		elsif ($config{'compressed'}) {
			# All compressed versions
			foreach $l (&all_log_files($file)) {
				$c = &catter_command($l);
				push(@cats, $c) if ($c);
				}
			}
		else {
			# Just the one log
			@cats = ( "cat ".quotemeta($file) );
			}
		$cat = "(".join(" ; ", @cats).")";
		$got = &foreign_call("proc", "safe_process_exec",
			"$cat | grep -i $filter | $tailcmd",
			0, 0, STDOUT, undef, 1, 0, undef, 1);
	} else {
		# Not filtering .. so cat the most recent non-empty file
		if ($cmd) {
			# Getting output from a command
			$catter = $cmd;
			}
		else {
			# Find the first non-empty file, newest first
			$catter = "cat ".quotemeta($file);
			if (!-s $file && $config{'compressed'}) {
				foreach $l (reverse(&all_log_files($file))) {
					next if (!-s $l);
					$c = &catter_command($l);
					if ($c) {
						$catter = $c;
						last;
						}
					}
				}
			}
		$got = &foreign_call("proc", "safe_process_exec",
			$catter." | $tailcmd", 
			0, 0, STDOUT, undef, 1, 0, undef, 1);
		}
	print "<i>$text{'view_empty'}</i>\n" if (!$got);
	print "</pre>\n";
	&filter_form();
	&ui_print_footer(
		$access{'noedit'} || $other || $in{'file'} || $in{'extra'} ?
		() : ( "edit_log.cgi?idx=$in{'idx'}", $text{'edit_return'} ),
		"", $text{'index_return'});
	exit;
	}
else {
	# saving or updating a log
	$access{'noedit'} && &error($text{'edit_ecannot'});
	$access{'syslog'} || &error($text{'edit_ecannot'});
	&error_setup($text{'save_err'});

	# Validate destination section
	if ($in{'mode'} == 0) {
		open(FILE, ">>$in{'file'}") ||
			&error(&text('save_efile', $in{'file'}, $!));
		close(FILE);
		&system_logged("chmod go-wx ".quotemeta($in{'file'}));
		$log->{'file'} = $in{'file'};
		$log->{'sync'} = $in{'sync'};
		}
	elsif ($in{'mode'} == 1 && $config{'pipe'} == 1) {
		-w $in{'pipe'} || &error(&text('save_epipe', $in{'pipe'}));
		$log->{'pipe'} = $in{'pipe'};
		}
	elsif ($in{'mode'} == 1 && $config{'pipe'} == 2) {
		$in{'pipe'} || &error($text{'save_epipe2'});
		$log->{'pipe'} = $in{'pipe'};
		}
	elsif ($in{'mode'} == 2) {
		gethostbyname($in{'host'}) ||
			&error(&text('save_ehost', $in{'host'}));
		$log->{'host'} = $in{'host'};
		}
	elsif ($in{'mode'} == 3) {
		@users = split(/\s+/, $in{'users'});
		@users || &error($text{'save_enousers'});
		foreach $u (@users) {
			defined(getpwnam($u)) ||
				&error(&text('save_euser', $u));
			}
		$log->{'users'} = \@users;
		}
	elsif ($in{'mode'} == 5) {
		-S $in{'socket'} || &error($text{'save_esocket'});
		$log->{'socket'} = $in{'socket'};
		}
	else {
		$log->{'all'} = 1;
		}
	$log->{'active'} = $in{'active'};
	if ($config{'tags'} && $in{'tag'} ne '') {
		$log->{'section'} = $conf->[$in{'tag'}];
		}

	# Parse message types section
	for($i=0; defined($in{"fmode_$i"}); $i++) {
		local ($f, $p);
		if ($in{"fmode_$i"} == 0) {
			next if (!$in{"facil_$i"});
			$f = $in{"facil_$i"};
			}
		else {
			@facils = split(/\s+/, $in{"facils_$i"});
			@facils || &error($text{'save_efacils'});
			$f = join(",", @facils);
			}
		if ($in{"pmode_$i"} == 0) {
			$p = 'none';
			}
		elsif ($in{"pmode_$i"} == 1) {
			$p = '*';
			}
		else {
			$p = $in{"pdir_$i"}.$in{"pri_$i"};
			$in{"pri_$i"} || &error($text{'save_epri'});
			}
		push(@sel, "$f.$p");
		}
	@sel || &error($text{'save_esel'});
	$log->{'sel'} = \@sel;
	if ($in{'new'}) {
		&can_edit_log($log) || &error($text{'save_ecannot3'});
		&lock_file($log->{'cfile'});
		$log->{'cfile'} = $config{'syslog_conf'};
		&create_log($log);
		&unlock_file($log->{'cfile'});
		}
	else {
		&can_edit_log($log) || &error($text{'save_ecannot4'});
		$old = $conf->[$in{'idx'}];
		$log->{'cfile'} = $old->{'cfile'};
		&lock_file($old->{'cfile'});
		$log->{'format'} = $old->{'format'};	# Copy for now
		&can_edit_log($old) || &error($text{'save_ecannot5'});
		&update_log($old, $log);
		&unlock_file($old->{'cfile'});
		}
	&redirect("");
	}
&log_line($log) =~ /(\S+)$/;
&webmin_log($in{'delete'} ? "delete" :
	    $in{'new'} ? "create" : "modify", "log", "$1", $log);

sub filter_form
{
print "<form action=save_log.cgi style='margin-left:1em'>\n";
print &ui_hidden("idx", $in{'idx'}),"\n";
print &ui_hidden("oidx", $in{'oidx'}),"\n";
print &ui_hidden("omod", $in{'omod'}),"\n";
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_hidden("extra", $in{'extra'}),"\n";
print &ui_hidden("view", 1),"\n";

print &text('view_header', &ui_textbox("lines", $lines, 3),
	    "<tt>".&html_escape($log->{'file'})."</tt>"),"\n";
print "&nbsp;&nbsp;\n";
print &text('view_filter', &ui_textbox("filter", $in{'filter'}, 25)),"\n";
print "&nbsp;&nbsp;\n";
print "<input type=submit value='$text{'view_refresh'}'></form>\n";
}

