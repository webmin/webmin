#!/usr/local/bin/perl
# index.cgi
# Display syslog rules

require './syslog-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("syslog", "man", "doc"));

if ($config{'m4_conf'}) {
	# Does the config file need to be passed through m4?
	if (&needs_m4()) {
		# syslog.conf has m4 directives .. ask the user if he wants
		# to filter the file
		print "<p>",&text('index_m4msg',
				  "<tt>$config{'syslog_conf'}</tt>"),"\n";
		print "<center><form action=m4.cgi>\n";
		print "<input type=submit value='$text{'index_m4'}'>\n";
		print "</form></center>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	}

if (!-r $config{'syslog_conf'}) {
	# Suggest using a new module
	my $index_econf2;
	if (&has_command('systemctl')) {
		if (&foreign_available('logviewer')) {
			my %logviewer_text = &load_language('logviewer');
			$index_econf2 = &text('index_econf2',
				$logviewer_text{'index_title'},
				"@{[&get_webprefix()]}/logviewer") . "<p><br>";
			}
		}
	# Not installed (maybe using syslog-ng)
	&ui_print_endpage($index_econf2 . &text('index_econf', "<tt>$config{'syslog_conf'}</tt>", "../config.cgi?$module_name"));
	}

# Display syslog rules
@links = ( );
if ($access{'syslog'}) {
	$conf = &get_config();
	push(@links, &ui_link("edit_log.cgi?new=1", $text{'index_add'}) ) if (!$access{'noedit'});
	}
print &ui_links_row(\@links);
print &ui_columns_start([
	$text{'index_to'},
	$config{'tags'} ? ( $text{'index_tag'} ) : ( ),
	$text{'index_active'},
	$text{'index_rule'}, "" ], 100);
if ($access{'syslog'}) {
	foreach $c (@$conf) {
		next if ($c->{'tag'});
		next if (!&can_edit_log($c));
		local @cols;
		local $name;
		if ($c->{'file'}) {
			$name = &text('index_file',
				"<tt>".&html_escape($c->{'file'})."</tt>");
			}
		elsif ($c->{'pipe'} && $config{'pipe'} == 1) {
			$name = &text('index_pipe',
				"<tt>".&html_escape($c->{'pipe'})."</tt>");
			}
		elsif ($c->{'pipe'} && $config{'pipe'} == 2) {
			$name = &text('index_pipe2',
				"<tt>".&html_escape($c->{'pipe'})."</tt>");
			}
		elsif ($c->{'host'}) {
			$name = &text('index_host',
				"<tt>".&html_escape($c->{'host'})."</tt>");
			}
		elsif ($c->{'socket'}) {
			$name = &text('index_socket',
				"<tt>".&html_escape($c->{'socket'})."</tt>");
			}
		elsif ($c->{'all'}) {
			$name = $text{'index_all'};
			}
		else {
			$name = &text('index_users',
				"<tt>".join(" ", map { &html_escape($_) }
						 @{$c->{'users'}})."</tt>");
			}
		if ($access{'noedit'}) {
			push(@cols, $name);
			}
		else {
			push(@cols, &ui_link("edit_log.cgi?".
				    "idx=".$c->{'index'}, $name) );
			}
		if ($config{'tags'}) {
			push(@cols, $c->{'section'}->{'tag'} eq '*' ?
				      $text{'all'} : $c->{'section'}->{'tag'});
			}
		push(@cols, $c->{'active'} ? $text{'yes'} :
				"<font color=#ff0000>$text{'no'}</font>");
		push(@cols, join("&nbsp;;&nbsp;",
			   map { &html_escape($_) } @{$c->{'sel'}}));
		if ($c->{'file'} && -f $c->{'file'}) {
			push(@cols, &ui_link("save_log.cgi?idx=".$c->{'index'}."&".
			      "view=1", $text{'index_view'}) );
			}
		else {
			push(@cols, "");
			}
		print &ui_columns_row(\@cols);
		}
	}

# Display logs from other modules
if ($config{'others'} && $access{'others'}) {
	@others = &get_other_module_logs();
	}
if (@others) {
	$cols = $config{'tags'} ? 5 : 4;
	foreach $o (@others) {
		next if (!&can_edit_log($o));
		local @cols;
		if ($o->{'file'}) {
			push(@cols, &text('index_file', "<tt>".&html_escape($o->{'file'})."</tt>"));
			}
		else {
			push(@cols, &text('index_cmd', "<tt>".&html_escape($o->{'cmd'})."</tt>"));
			}
		if ($config{'tags'}) {
			push(@cols, "");
			}
		push(@cols, $o->{'active'} ? $text{'yes'} :
				    "<font color=#ff0000>$text{'no'}</font>");
		push(@cols, &html_escape($o->{'desc'}));
		push(@cols, &ui_link("save_log.cgi?oidx=$o->{'mindex'}".
			   "&omod=$o->{'mod'}&view=1", $text{'index_view'}) );
		print &ui_columns_row(\@cols);
		}
	}

# Display extra log files
foreach $e (&extra_log_files()) {
	next if (!&can_edit_log($e));
	local @cols;
	push(@cols, &text('index_file', "<tt>".&html_escape($e->{'file'})."</tt>"));
	if ($config{'tags'}) {
		push(@cols, "");
		}
	push(@cols, $text{'yes'});
	push(@cols, &html_escape($e->{'desc'}));
	push(@cols, &ui_link("save_log.cgi?extra=$e->{'file'}&view=1", $text{'index_view'}) );
	print &ui_columns_row(\@cols);
	}

print &ui_columns_end();
print &ui_links_row(\@links);
print "<p>\n";

if ($access{'any'}) {
	# Can view any log (under allowed dirs)
	print &ui_form_start("save_log.cgi");
	print &ui_hidden("view", 1),"\n";
	print "<b>$text{'index_viewfile'}</b>\n",
	      &ui_textbox("file", undef, 50),"\n",
	      &file_chooser_button("file", 0, 1),"\n",
	      &ui_submit($text{'index_viewok'}),"\n";
	print &ui_form_end();
	}

# Buttons to restart/start syslogd
if (!$access{'noedit'}) {
	print &ui_hr();
	$pid = &get_syslog_pid();
	print &ui_buttons_start();
	if ($pid) {
		print &ui_buttons_row("restart.cgi",
				      $text{'index_restart'},
				      $text{'index_restartmsg'});
		}
	else {
		print &ui_buttons_row("start.cgi",
				      $text{'index_start'},
				      &text('index_startmsg',
					    "<tt>$config{'syslogd'}</tt>"));
		}
	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});

