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

	# System logs from other modules
	my @foreign_syslogs;
	if (&foreign_available('syslog') &&
	    &foreign_installed('syslog')) {
		&foreign_require('syslog');
		my $conf = &syslog::get_config();
		foreach $c (@$conf) {
			next if ($c->{'tag'});
			next if (!&can_edit_log($c));
			local @cols;
			local $name;
			if ($c->{'file'}) {
				$name = &text('index_file',
					"<tt>".&html_escape($c->{'file'})."</tt>");
				}
			if ($c->{'file'} && -f $c->{'file'}) {
				push(@cols, $name);
				push(@cols, join("&nbsp;;&nbsp;",
					   map { &html_escape($_) } @{$c->{'sel'}}));
				push(@cols, &ui_link("view_log.cgi?idx=syslog-".$c->{'index'}."&".
				      "view=1", $text{'index_view'}) );
				push(@col1, \@cols);
				push(@foreign_syslogs, $c->{'file'});
				}
			}
		}
	if (&foreign_available('syslog-ng') &&
	    &foreign_installed('syslog-ng')) {
		&foreign_require('syslog-ng');
		my $conf = &syslog_ng::get_config();
		my @dests = &syslog_ng::find("destination", $conf);
		foreach my $dest (@dests) {
			my $file = &syslog_ng::find_value("file", $dest->{'members'});
			my ($type, $typeid) = &syslog_ng::nice_destination_type($dest);
			next if (grep(/^$file$/, @foreign_syslogs));
			next if ($file !~ /^\//);
			if ($typeid == 0 && -f $file) {
				my @cols;
				if ($file && -f $file) {
					next if (!&can_edit_log({'file' => $file}));
					push(@cols, &text('index_file',
						"<tt>".&html_escape($file)."</tt>"));
					push(@cols, "&nbsp;;&nbsp;$dest->{'value'}");
					push(@cols, &ui_link("view_log.cgi?idx=syslog-ng-".$dest->{'index'}."&".
					      "view=1", $text{'index_view'}) );
					push(@col1, \@cols);
					}
				}
			
			}
		}
	}

# Display logs from other modules
if ($config{'others'} && $access{'others'}) {
	@others = &get_other_module_logs();
	if (@others) {
		foreach $o (@others) {
			local @cols;
			if ($o->{'file'}) {
				push(@cols, &text('index_file',
				    "<tt>".&html_escape($o->{'file'})."</tt>"));
				}
			else {
				push(@cols, &text('index_cmd',
				    "<tt>".&html_escape($o->{'cmd'})."</tt>"));
				}
			push(@cols, &html_escape($o->{'desc'}));
			push(@cols, &ui_link("view_log.cgi?oidx=$o->{'mindex'}".
				"&omod=$o->{'mod'}&view=1", $text{'index_view'}) );
			push(@col2, \@cols);
			}
		}
	}

# Display extra log files
foreach $e (&extra_log_files()) {
	local @cols;
	if ($e->{'file'}) {
		push(@cols, &text('index_file',
			"<tt>".&html_escape($e->{'file'})."</tt>"));
		}
	else {
		push(@cols, &text('index_cmd',
			"<tt>".&html_escape($e->{'cmd'})."</tt>"));
		}
	push(@cols, &html_escape($e->{'desc'}));
	push(@cols, &ui_link("view_log.cgi?extra=".&urlize($e->{'file'} || $e->{'cmd'})."&view=1", $text{'index_view'}) );
	push(@col3, \@cols);
	}

# Print sorted table with logs files and commands
my @acols = (@col1, @col2, @col3);
print &ui_columns_start( @acols ? [
	$text{'index_to'},
	$text{'index_rule'}, "" ] : [ ], 100);
if (@acols) {
	@acols = sort { $a->[2] cmp $b->[2] } @acols;
	foreach my $col (@acols) {
		print &ui_columns_row($col);
		}
	}
else {
	print &ui_columns_row([$text{'index_elogs'}], [" colspan='3' style='text-align: center'"], 3);
	}
print &ui_columns_end();
print "<p>\n";

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

