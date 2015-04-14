#!/usr/local/bin/perl
# edit_proc.cgi
# Display information about a process

require './proc-lib.pl';
&ui_print_header(undef, $text{'edit_title'}, "", "edit_proc");
%pinfo = &process_info($ARGV[0]);
&can_edit_process($pinfo{'user'}) || &error($text{'edit_ecannot'});

# Check if the process is still running
if (!%pinfo) {
	print "<b>$text{'edit_gone'}</b> <p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

print &ui_table_start($text{'edit_title'}, "width=100%", 4,
		      [ "width=20%", "width=30%", "width=20%", "width=30%" ]);

# Full command
print &ui_table_row($text{'command'},
	"<tt>".&html_escape($pinfo{args})."</tt>", 3);

# Process ID
print &ui_table_row($text{'pid'}, $pinfo{pid});

# Parent process
if ($pinfo{ppid}) {
	local %ppinfo = &process_info($pinfo{ppid});
	print &ui_table_row($text{'parent'},
		&ui_link("edit_proc.cgi?".$ppinfo{pid},
                &cut_string($ppinfo{'args'}, 30)) );
	}
else {
	print &ui_table_row($text{'parent'}, $text{'edit_none'});
	}

# Unix user
print &ui_table_row($text{'owner'}, $pinfo{'user'});

# CPU use
print &ui_table_row($text{'cpu'}, $pinfo{'cpu'});

# Memory size
print &ui_table_row($text{'size'}, $pinfo{'bytes'} ? &nice_size($pinfo{'bytes'})
						   : $pinfo{'size'});

# Run time
print &ui_table_row($text{'runtime'}, $pinfo{'time'});

# Nice level
print &ui_form_start("renice_proc.cgi");
print &ui_hidden("pid", $ARGV[0]);
print &ui_table_row(&hlink($text{'nice'},"nice"),
	&indexof($pinfo{nice}, @nice_range) < 0 ? $pinfo{nice} :
		&nice_selector("nice", $pinfo{nice}).
		&ui_submit($text{'edit_change'}), 3);

# IO scheduling class, if support
if (defined(&os_list_scheduling_classes) &&
    (@classes = &os_list_scheduling_classes())) {
	($class, $prio) = &os_get_scheduling_class($pinfo{'pid'});
	($got) = grep { $_->[0] == $class } @classes;
	if (!$got) {
		# Some unknown class, probably 'none'
		unshift(@classes, [ $class, $text{'default'} ]);
		}
	print &ui_table_row(&hlink($text{'sclass'},"sclass"),
		&ui_select("sclass", $class, \@classes));
	print &ui_table_row(&hlink($text{'sprio'},"sprio"),
		&ui_select("sprio", $prio,
			   [ &os_list_scheduling_priorities() ], 1, 0, 1));
	}

print &ui_form_end();

# Extra OS-specific info
foreach $k (keys %pinfo) {
	if ($k =~ /^_/) {
		print &ui_table_row($info_arg_map{$k}, $pinfo{$k});
		}
	}
print &ui_table_end();

print "<table width=100%><tr>\n";
if ($access{'simple'}) {
	# Just display buttons for common signals
	print &ui_form_start("kill_proc.cgi");
	print &ui_hidden("pid", $pinfo{pid});
	print "<td nowrap>\n";
	foreach $s ('KILL', 'TERM', 'HUP', 'STOP', 'CONT') {
		print &ui_submit($text{"kill_".lc($s)}, $s);
		}
	print "</td>\n";
	print &ui_form_end();
	}
else {
	# Allow the sending of any signal
	print &ui_form_start("kill_proc.cgi");
	print &ui_hidden("pid", $pinfo{pid});
	print "<td nowrap>\n";
	print &ui_submit($text{'edit_kill'});
	print &ui_select("signal", "HUP", [ &supported_signals() ]);

	print "&nbsp;" x 4;
	print &ui_submit($text{'edit_sigterm'}, 'TERM');
	print &ui_submit($text{'edit_sigkill'}, 'KILL');
	print "&nbsp;" x 4;
	print &ui_submit($text{'edit_sigstop'}, 'STOP');
	print &ui_submit($text{'edit_sigcont'}, 'CONT');
	print "</td>\n";
	print &ui_form_end();
	}

if ($has_trace_command) {
	# Show button to trace syscalls
	print &ui_form_start("trace.cgi");
	print &ui_hidden("pid", $pinfo{pid});
	print "<td align=right width=10>",
	      &ui_submit($text{'edit_trace'}),"</td>\n";
	print &ui_form_end();
	}

if ($has_lsof_command) {
	# Show button to display currently open files
	print &ui_form_start("open_files.cgi");
	print &ui_hidden("pid", $pinfo{pid});
	print "<td align=right width=10>",
	      &ui_submit($text{'edit_open'}),"</td></form>\n";
	print &ui_form_end();
	}
print "</tr></table><p>\n";

# Sub-processes table
@sub = grep { $_->{'ppid'} == $pinfo{pid} } &list_processes();
if (@sub) {
	print &ui_columns_start([ $text{'edit_subid'},
				  $text{'edit_subcmd'} ], 100);
	@sub = sort { $a->{'pid'} <=> $b->{'pid'} } @sub;
	foreach $s (@sub) {
		local $p = $s->{'pid'};
		print &ui_columns_row([
			&ui_link("edit_proc.cgi?".$p, $p),
			&cut_string($s->{args}, 80),
			]);
		}
	print &ui_columns_end();
	}

&ui_print_footer("", $text{'index_return'});

