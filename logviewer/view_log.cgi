#!/usr/local/bin/perl
# view_log.cgi
# Save, create, delete or view a log

require './logviewer-lib.pl';
&ReadParse();
&foreign_require("proc", "proc-lib.pl");

if ($in{'view'}) {
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
		# From systemctl commands
		if ($in{'idx'} =~ /^journal-/) {
			my @systemctl_cmds = &get_systemctl_cmds();
			my ($log) = grep { $_->{'id'} eq $in{'idx'} } @systemctl_cmds;
			&can_edit_log($log) && $access{'syslog'} ||
				&error($text{'save_ecannot2'});
			$cmd = $log->{'cmd'};
			}

		# System logs from other modules
		elsif ($in{'idx'} =~ /^syslog-ng-/) {
			if (&foreign_available('syslog-ng') &&
			    &foreign_installed('syslog-ng')) {
				&foreign_require('syslog-ng');
				my $conf = &syslog_ng::get_config();
				my @dests = &syslog_ng::find("destination", $conf);
				my $iid = $in{'idx'};
				$iid =~ s/^syslog-ng-//;
				my $log = $conf->[$iid];
				my $dfile = &syslog_ng::find_value("file", $log->{'members'});
				&can_edit_log({'file' => $dfile}) && $access{'syslog'} ||
					&error($text{'save_ecannot2'});
				$file = $dfile;
				}
			}
		elsif ($in{'idx'} =~ /^syslog-/) {
			if (&foreign_available('syslog') &&
			    &foreign_installed('syslog')) {
				&foreign_require('syslog');
				my $conf = &syslog::get_config();
				my $iid = $in{'idx'};
				$iid =~ s/^syslog-//;
				my $log = $conf->[$iid];
				&can_edit_log($log) && $access{'syslog'} ||
					&error($text{'save_ecannot2'});
				$file = $log->{'file'};
				}
			}
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
		($extra) = grep { $_->{'file'} eq $in{'extra'} ||
				  $_->{'cmd'} eq $in{'extra'} } @extras;
		$extra || &error($text{'save_ecannot7'});
		&can_edit_log($extra) || &error($text{'save_ecannot2'});
		$file = $extra->{'file'};
		$cmd = $extra->{'cmd'};
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
	$in{'nonavlinks'} ? &ui_print_footer() :
	                    &ui_print_footer("", $text{'index_return'});
	exit;
	}

sub filter_form
{
print &ui_form_start("view_log.cgi");
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
my $text_view_header = 'view_header';
if ($access{'syslog'}) {
	# Logs from syslog
	my @systemctl_cmds = &get_systemctl_cmds();
	foreach $c (@systemctl_cmds) {
		next if (!&can_edit_log($c));
		push(@logfiles, [ $c->{'id'}, "$c->{'desc'}" ]);
		$found++ if ($c->{'id'} eq $in{'idx'});
		}

	# System logs from other modules
	my @foreign_syslogs;
	if (&foreign_available('syslog') &&
	    &foreign_installed('syslog')) {
		&foreign_require('syslog');
		my $conf = &syslog::get_config();
		foreach $c (@$conf) {
			next if ($c->{'tag'});
			next if (!&can_edit_log($c));
			next if (!$c->{'file'} || !-f $c->{'file'});
			push(@logfiles, [ "syslog-$c->{'index'}", $c->{'file'} ]);
			$found++ if ($c->{'file'} eq $file);
			push(@foreign_syslogs, $c->{'file'});
			}
		}
	if (&foreign_available('syslog-ng') &&
	    &foreign_installed('syslog-ng')) {
		&foreign_require('syslog-ng');
		my $conf = &syslog_ng::get_config();
		my @dests = &syslog_ng::find("destination", $conf);
		foreach my $dest (@dests) {
			my $dfile = &syslog_ng::find_value("file", $dest->{'members'});
			my ($type, $typeid) = &syslog_ng::nice_destination_type($dest);
			next if (grep(/^$dfile$/, @foreign_syslogs));
			next if ($dfile !~ /^\//);
			if ($typeid == 0 && -f $dfile) {
				my @cols;
				if ($dfile && -f $dfile) {
					push(@logfiles, [ "syslog-ng-$dest->{'index'}", $dfile ]);
					$found++ if ($dfile eq $file);
					}
				}
			}
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
			  [ @logfiles ], undef, undef, undef, undef, "onChange='form.submit()'");
	}
else {
	$text_view_header = 'view_header2';
	$sel = "<tt>".&html_escape($in{'file'})."</tt>";
	print &ui_hidden("idx", $in{'idx'}),"\n";
	}

print &text($text_view_header, "&nbsp;" . &ui_textbox("lines", $lines, 3), "&nbsp;$sel"),"\n";
print "&nbsp;&nbsp;&nbsp;&nbsp;\n";
print &text('view_filter', "&nbsp;" . &ui_textbox("filter", $in{'filter'}, 25)),"\n";
print "&nbsp;&nbsp;\n";
print &ui_submit($text{'view_refresh'});
print &ui_form_end(),"<br>\n";
}

