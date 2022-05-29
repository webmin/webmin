#!/usr/local/bin/perl
# index.cgi
# Display syslog rules

require './logviewer-lib.pl';

&ui_print_header($text{'index_subtitle'}, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("systemd-journal journalctl", "man", "doc"));

if (!&has_command('journalctl')) {
	# Not installed
	&ui_print_endpage(&text('index_econf', "<tt>$config{'syslog_conf'}</tt>", "../config.cgi?$module_name"));
	}

# Display syslog rules
my @col1;
my @col2;
my @col3;
if ($access{'syslog'}) {
	my @systemctl_cmds = &get_systemctl_cmds();
	foreach $o (@systemctl_cmds) {
		local @cols;
		push(@cols, &text('index_cmd', "<tt>".$o->{'cmd'}."</tt>"));
		push(@cols, $o->{'desc'});
		push(@cols, &ui_link("view_log.cgi?idx=$o->{'id'}&view=1", $text{'index_view'}) );
		push(@col1, \@cols);
		}
	}

# Display logs from other modules
if ($config{'others'} && $access{'others'}) {
	@others = &get_other_module_logs();
	if (@others) {
		foreach $o (@others) {
			local @cols;
			if ($o->{'file'}) {
				push(@cols, &text('index_file',"<tt>$o->{'file'}</tt>"));
				}
			else {
				push(@cols, &text('index_cmd', "<tt>".$o->{'cmd'}."</tt>"));
				}
			push(@cols, $o->{'desc'});
			push(@cols, &ui_link("view_log.cgi?oidx=$o->{'mindex'}".
				"&omod=$o->{'mod'}&view=1", $text{'index_view'}) );
			push(@col2, \@cols);
			}
		}
	}

# Display extra log files
foreach $e (&extra_log_files()) {
	local @cols;
	push(@cols, &text('index_file', $e->{'file'}));
	push(@cols, $e->{'desc'});
	push(@cols, &ui_link("view_log.cgi?extra=$e->{'file'}&view=1", $text{'index_view'}) );
	push(@col3, \@cols);
	}

# Print sorted table with logs files and commands
my @acols = (@col1, @col2, @col3);
if (@acols) {
	print &ui_columns_start([
		$text{'index_to'},
		$text{'index_rule'}, "" ], 100);
	@acols = sort { $a->[0] cmp $b->[0] } @acols;
	foreach my $col (@acols) {
		print &ui_columns_row($col);
		}
	print &ui_columns_end();
	print "<p>\n";
	}
else {
	print &ui_columns_start([ ], 100);
	print &ui_columns_row([$text{'index_elogs'}], [" style='text-align: center'"]);
	print &ui_columns_end();
	print "<p>\n";
	}

if ($access{'any'}) {
	# Can view any log (under allowed dirs)
	print &ui_form_start("view_log.cgi");
	print &ui_hidden("view", 1),"\n";
	print "$text{'index_viewfile'}&nbsp;&nbsp;\n",
	      &ui_textbox("file", undef, 50),"\n",
	      &file_chooser_button("file", 0, 1),"\n",
	      &ui_submit($text{'index_viewok'}),"\n";
	print &ui_form_end();
	}

&ui_print_footer("/", $text{'index'});

