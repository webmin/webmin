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
	@extras = &extra_log_files();
	if ($in{'idx'} =~ /^\//) {
		# The drop-down selector on this page has chosen a file
		if (&indexof($in{'idx'}, (map { $_->{'file'} } @extras)) >= 0) {
			$in{'extra'} = $in{'idx'};
			delete($in{'file'});
			}
		else {
			$in{'file'} = $in{'idx'};
			delete($in{'extra'});
			}
		delete($in{'idx'});
		delete($in{'oidx'});
		}
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
			 $in{'linktitle'} || $text{'view_title'}, "", undef, undef, $in{'nonavlinks'});

	$lines = $in{'lines'} ? int($in{'lines'}) : int($config{'lines'});
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
		if ($config{'reverse'}) {
			$tailcmd .= " | tac";
			}
		$eflag = $gconfig{'os_type'} =~ /-linux/ ? "-E" : "";
		$dashflag = $gconfig{'os_type'} =~ /-linux/ ? "--" : "";
		if (@cats) {
			$got = &proc::safe_process_exec(
				"$cat | grep -i -a $eflag $dashflag $filter ".
				"| $tailcmd",
				0, 0, STDOUT, undef, 1, 0, undef, 1);
			}
		else {
			$got = undef;
			}
	} else {
		# Not filtering .. so cat the most recent non-empty file
		if ($cmd) {
			# Getting output from a command
			$fullcmd = $cmd." | ".$tailcmd;
			}
		elsif ($config{'compressed'}) {
			# Cat all compressed files
			local @cats;
			$total = 0;
			foreach $l (reverse(&all_log_files($file))) {
				next if (!-s $l);
				$c = &catter_command($l);
				if ($c) {
					$len = int(&backquote_command(
							"$c | wc -l"));
					$total += $len;
					push(@cats, $c);
					last if ($total > $in{'lines'});
					}
				}
			if (@cats) {
				$cat = "(".join(" ; ", reverse(@cats)).")";
				$fullcmd = $cat." | ".$tailcmd;
				}
			else {
				$fullcmd = undef;
				}
			}
		else {
			# Just run tail on the file
			$fullcmd = $tailcmd." ".quotemeta($file);
			}
		if ($config{'reverse'} && $fullcmd) {
			$fullcmd .= " | tac";
			}
		if ($fullcmd) {
			$got = &proc::safe_process_exec(
				$fullcmd, 0, 0, STDOUT, undef, 1, 0, undef, 1);
			}
		else {
			$got = undef;
			}
		}
	print "<i>$text{'view_empty'}</i>\n" if (!$got);
	print "</pre>\n";
	&filter_form();
	$in{'nonavlinks'} ? &ui_print_footer() : &ui_print_footer(
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
		my $user = $config{'log_user'} || 'root';
		my $group = $config{'log_group'};
		&set_ownership_permissions($user, $group, 644, $in{'file'});
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
		my $host = $in{'host'};
		$host =~ s/:\d+$//;
		&to_ipaddress($host) || &to_ip6address($host) ||
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
print &ui_form_start("save_log.cgi");
print &ui_hidden("nonavlinks", $in{'nonavlinks'} ? 1 : 0),"\n";
print &ui_hidden("linktitle", $in{'linktitle'}),"\n";
print &ui_hidden("oidx", $in{'oidx'}),"\n";
print &ui_hidden("omod", $in{'omod'}),"\n";
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_hidden("extra", $in{'extra'}),"\n";
print &ui_hidden("view", 1),"\n";

# Create list of logs and selector
my @logfiles;
my $found = 0;
if ($access{'syslog'}) {
	# Logs from syslog
	my $conf = &get_config();
	foreach $c (@$conf) {
		next if ($c->{'tag'});
		next if (!&can_edit_log($c));
		next if (!$c->{'file'} || !-f $c->{'file'});
		push(@logfiles, [ $c->{'index'}, $c->{'file'} ]);
		$found++ if ($c->{'file'} eq $file);
		}
	}
if ($config{'others'} && $access{'others'}) {
	foreach my $o (&get_other_module_logs()) {
		next if (!&can_edit_log($o));
		next if (!$o->{'file'});
		push(@logfiles, [ $o->{'file'} ]);
		$found++ if ($o->{'file'} eq $file);
		}
	}
foreach $e (&extra_log_files()) {
	next if (!&can_edit_log($e));
	push(@logfiles, [ $e->{'file'} ]);
	$found++ if ($e->{'file'} eq $file);
	}
if (@logfiles && $found) {
	$sel = &ui_select("idx", $in{'idx'} eq '' ? $file : $in{'idx'},
			  [ @logfiles ]);
	}
else {
	$sel = "<tt>".&html_escape($log->{'file'})."</tt>";
	print &ui_hidden("idx", $in{'idx'}),"\n";
	}

print &text('view_header', "&nbsp;" . &ui_textbox("lines", $lines, 3), $sel),"\n";
print "&nbsp;&nbsp;&nbsp;&nbsp;\n";
print &text('view_filter', "&nbsp;" . &ui_textbox("filter", $in{'filter'}, 25)),"\n";
print "&nbsp;&nbsp;\n";
print &ui_submit($text{'view_refresh'});
print &ui_form_end(),"<br>\n";
}

