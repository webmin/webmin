#!/usr/local/bin/perl
# view_log.cgi
# Save, create, delete or view a log

require './logviewer-lib.pl';
&ReadParse();
&foreign_require("proc", "proc-lib.pl");

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
my @journal_since =
	("-b", "-S '7 days ago'", 
	 "-S '24 hours ago'", "-S '8 hours ago'",
	 "-S '1 hour ago'", "-S '30 minutes ago'",
	 "-S '10 minutes ago'", "-S '1 minute ago'");
if ($in{'idx'} ne '') {
	# From systemctl commands
	if ($in{'idx'} =~ /^journal-/) {
		my @systemctl_cmds = &get_systemctl_cmds(1);
		my ($log);
		if ($in{'idx'} eq 'journal-u') {
			($log) = grep { $_->{'cmd'} =~ /-u\s+\w+/ } @systemctl_cmds;
			$in{'idx'} = $log->{'id'};
			}
		else {
			($log) = grep { $_->{'id'} eq $in{'idx'} } @systemctl_cmds;
		}
		# If reverse is set, add it to the command
		if ($config{'reverse'}) {
			$log->{'cmd'} .= " -r";
			}
		# If since is set and allowed, add it to the command
		if ($in{'since'} && grep { $_ eq $in{'since'} } @journal_since) {
			$log->{'cmd'} .= " $in{'since'}";
			}
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
my $no_navlinks = $in{'nonavlinks'} == 1 ? 1 : undef;
my $skip_index = $config{'skip_index'} == 1 ? 1 : undef;
my $help_link = (!$no_navlinks && $skip_index) ?
	&help_search_link("systemd-journal journalctl", "man", "doc") : undef;
my $no_links = $no_navlinks || $skip_index;
my $cmd_unpacked = $cmd;
$cmd_unpacked =~ s/\\x([0-9A-Fa-f]{2})/pack('H2', $1)/eg;
my $view_title = $in{'idx'} =~ /^journal/ ?
	$text{'view_titlejournal'} : $text{'view_title'};
&ui_print_header("<tt>".&html_escape($file || $cmd_unpacked)."</tt>",
		 $in{'linktitle'} || $view_title, "", undef,
		 	!$no_navlinks && $skip_index,
			($no_navlinks || $skip_index) ? 1 : undef,
			0, $help_link);

$lines = $in{'lines'} ? int($in{'lines'}) : int($config{'lines'});
$filter = $in{'filter'} ? quotemeta($in{'filter'}) : "";

&filter_form();

$| = 1;
print "<pre>";
local $tailcmd = $config{'tail_cmd'} || "tail -n LINES";
$tailcmd =~ s/LINES/$lines/g;
my $safe_proc_out;
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
		$tailcmd .= " | tac" if ($fullcmd !~ /journalctl/);
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
		$fullcmd = $cmd.($fullcmd !~ /journalctl/ ? "" : " | ".$tailcmd);
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
		$fullcmd .= " | tac" if ($fullcmd !~ /journalctl/);
		}
	if ($fullcmd) {
		open(my $output_fh, '>', \$safe_proc_out);
		$got = &proc::safe_process_exec(
			$fullcmd, 0, 0, $output_fh, undef, 1, 0, undef, 1);
		close($output_fh);
		print $safe_proc_out if ($safe_proc_out !~ /-- No entries --/m);
		}
	else {
		$got = undef;
		}
	}
print "<i>$text{'view_empty'}</i>\n"
	if (!$got || $safe_proc_out =~ /-- No entries --/m);
print "</pre>\n";
&filter_form();
if ($no_links) {
	&ui_print_footer();
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

sub filter_form
{
print &ui_form_start("view_log.cgi");
if ($no_navlinks) {
	print &ui_hidden("nonavlinks", $no_navlinks),"\n";
	}
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
	my @systemctl_cmds = &get_systemctl_cmds(1);
	foreach $c (@systemctl_cmds) {
		next if (!&can_edit_log($c));
		my $icon = $c->{'id'} =~ /journal-(a|x)/ ? "&#x25E6;&nbsp; " : "";
		push(@logfiles, [ $c->{'id'}, $icon.$c->{'desc'} ]);
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
			  [ @logfiles ], undef, undef, undef, undef,
			  	"onChange='form.submit()' style='max-width: 240px'");
	if ($in{'idx'} =~ /^journal-/) {
		my $selots;
		for (my $i = 0; $i < @journal_since; $i++) {
			push(@$selots, [ $journal_since[$i],
					 $text{'journal_since'.$i} ]);
			}
		$sel .= "since&nbsp; " .
			&ui_select("since", $in{'since'}, $selots, undef,
			    undef, undef, undef, "onChange='form.submit()'");
		}
	}
else {
	$text_view_header = 'view_header2';
	print &ui_hidden("idx", $in{'idx'}),"\n";
	}

print &text($text_view_header, "&nbsp;" . &ui_textbox("lines", $lines, 3), "&nbsp;$sel"),"\n";
print "&nbsp;&nbsp;&nbsp;&nbsp;\n";
print &text('view_filter', "&nbsp;" . &ui_textbox("filter", $in{'filter'}, 12)),"\n";
print "&nbsp;&nbsp;\n";
print &ui_submit($text{'view_refresh'});
print &ui_form_end(),"<br>\n";
}

