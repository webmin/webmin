#!/usr/local/bin/perl
# index.cgi
# Display syslog rules

require './logviewer-lib.pl';

# Display syslog rules
my @col0;
my @col1;
my @col2;
my @col3;
my @lnks;
if ($access{'syslog'}) {
	my @systemctl_cmds = &get_systemctl_cmds();
	foreach $o (@systemctl_cmds) {
		local @cols;
		push(@cols, &text('index_cmd', "<tt>".
			&cleanup_destination($o->{'cmd'})."</tt>"));
		my $icon = $o->{'id'} =~ /journal-(a|x)/ ? "&#x25E6;&nbsp; " : "";
		push(@cols, $icon.&cleanup_description($o->{'desc'}));
		push(@cols, &ui_link("view_log.cgi?idx=$o->{'id'}&view=1",
			$text{'index_view'}) );
		push(@lnks, "view_log.cgi?idx=$o->{'id'}&view=1");
		push(@col0, \@cols);
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
				push(@cols, &ui_link("view_log.cgi?idx=syslog-".
					$c->{'index'}."&"."view=1", $text{'index_view'}) );
				push(@lnks, "view_log.cgi?idx=syslog-".
					$c->{'index'}."&"."view=1");
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
					push(@cols, &ui_link(
						"view_log.cgi?idx=syslog-ng-".
						$dest->{'index'}."&"."view=1",
						$text{'index_view'}) );
					push(@lnks, "view_log.cgi?idx=syslog-ng-".
						$dest->{'index'}."&"."view=1");
					@cols = sort { $a->[2] cmp $b->[2] } @cols;
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
			push(@cols, $o->{'desc'} ? &html_escape($o->{'desc'}) : "");
			push(@cols, &ui_link("view_log.cgi?oidx=$o->{'mindex'}".
				"&omod=$o->{'mod'}&view=1", $text{'index_view'}) );
			push(@lnks, "view_log.cgi?oidx=$o->{'mindex'}".
				"&omod=$o->{'mod'}&view=1");
			@cols = sort { $a->[2] cmp $b->[2] } @cols;
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
	push(@cols, $e->{'desc'} ? &html_escape($e->{'desc'}) : "");
	push(@cols, &ui_link("view_log.cgi?extra=".&urlize($e->{'file'} || $e->{'cmd'})."&view=1", $text{'index_view'}) );
	push(@lnks, "view_log.cgi?extra=".&urlize($e->{'file'} || $e->{'cmd'})."&view=1");
	@cols = sort { $a->[2] cmp $b->[2] } @cols;
	push(@col3, \@cols);
	}

# Print sorted table with logs files and commands
my @acols = (@col0, @col1, @col2, @col3);

my $print_header = sub {
	# Print the header
	&ui_print_header($text{'index_subtitle'}, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("systemd-journal journalctl", "man", "doc"));
	};

# If no logs are available just show the message
if (!@acols) {
	$print_header->();
	&ui_print_endpage($text{'index_elogs'});
	}

# If we jump directly to logs just redirect
if ($config{'skip_index'} == 1 && $lnks[0]) {
	&redirect($lnks[0]);
	return;
	}

# Print the header
$print_header->();

print &ui_columns_start( @acols ? [
	$text{'index_to'},
	$text{'index_rule'}, "" ] : [ ], 100);
foreach my $col (@acols) {
	print &ui_columns_row($col);
	}
print &ui_columns_end();
print "<p>\n";

if ($access{'any'} && $config{'log_any'} == 1) {
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

