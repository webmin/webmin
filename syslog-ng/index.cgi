#!/usr/local/bin/perl
# Show icons for syslog-ng destinations, filters, logs and options

require './syslog-ng-lib.pl';

# Make sure it is installed
$ver = &get_syslog_ng_version();
if (!$ver) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage(&text('index_eprog', "<tt>$config{'syslogng_cmd'}</tt>", "../config.cgi?$module_name"));
	}
if (!-r $config{'syslogng_conf'} && -r $config{'alt_syslogng_conf'}) {
	# Copy original template config file
	&copy_source_dest($config{'alt_syslogng_conf'},
			  $config{'syslogng_conf'});
	}
if (!-r $config{'syslogng_conf'}) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage(&text('index_econf', "<tt>$config{'syslogng_conf'}</tt>", "../config.cgi?$module_name"));
	}

&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		 &help_search_link("syslog-ng", "man", "doc", "google"),
		 undef, undef, &text('index_version', $ver));

# Show category icons
@pages = ( "options", "sources", "destinations", "filters", "logs" );
@links = map { "list_${_}.cgi" } @pages;
@titles = map { $text{$_."_title"} } @pages;
@icons = map { "images/${_}.gif" } @pages;
&icons_table(\@links, \@titles, \@icons, 5);

# Show start/stop buttons
print &ui_hr();
print &ui_buttons_start();
if (&is_syslog_ng_running()) {
	print &ui_buttons_row("apply.cgi", $text{'index_apply'},
			      $text{'index_applydesc'});
	print &ui_buttons_row("stop.cgi", $text{'index_stop'},
			      $text{'index_stopdesc'});
	}
else {
	print &ui_buttons_row("start.cgi", $text{'index_start'},
			      $text{'index_startdesc'});
	}
print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

