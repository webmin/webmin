#!/usr/local/bin/perl
# index.cgi
# Show all logs that are being rotated

require './logrotate-lib.pl';

# Make sure config file and program exists
if (!&has_command($config{'logrotate'})) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);
	print &ui_config_link('index_ecmd',
		        [ "<tt>$config{'logrotate'}</tt>", undef ]),"<p>\n";

	&foreign_require("software", "software-lib.pl");
	$lnk = &software::missing_install_link(
			"logrotate", $text{'index_logrotate'},
			"../$module_name/", $text{'index_title'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{'index'});
	exit;
	}
if (!-r $config{'logrotate_conf'}) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);
	&ui_print_endpage(
		&ui_config_link('index_econf',
			[ "<tt>$config{'logrotate_conf'}</tt>", undef ]));
	}

# Get the version
$logrotate_version = &get_logrotate_version(\$out);
if (!$logrotate_version) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);
	&ui_print_endpage(
		&text('index_eversion', "<tt>$config{'logrotate'} -v</tt>",
		      "<pre>$out</pre>"));
	}
&open_tempfile(VERSION, ">$module_config_directory/version");
&print_tempfile(VERSION, "$logrotate_version\n");
&close_tempfile(VERSION);
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		 &help_search_link("logrotate", "man", "doc", "google"),
		 undef, undef,
		 &text('index_version', $logrotate_version));

# Show table of log files
$conf = &get_config();
$defp = &get_period($conf);
foreach $c ($config{'sort_mode'} ?
	     (sort { $a->{'name'}->[0] cmp $b->{'name'}->[0] } @$conf) :
	     @$conf) {
	if ($c->{'members'}) {
		local $p = &get_period($c->{'members'}) || $defp;
		local $r = &find_value("postrotate", $c->{'members'});
		$r =~ s/\n/<br>\n/g;
		push(@table, [ &ui_link("edit_log.cgi?idx=".$c->{'index'},
			       join(" ", map { "<tt>$_</tt><br>" }
					     @{$c->{'name'}}) ),
			       $text{'period_'.$p} ||
				"<i>$text{'index_notset'}</i>",
			       $r ? "<tt><font size=-1>$r</font></tt>"
				  : "<i>$text{'index_nocmd'}</i>" ]);
		push(@tablelogs, $c);
		}
	}
if (@table) {
	print &ui_form_start("delete_logs.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   &ui_link("edit_log.cgi?new=1", $text{'index_add'}) );
	print &ui_links_row(\@links);
	@tds = ( "width=5", "nowrap valign=top", "valign=top", "valign=top" );
	print &ui_columns_start([ "",
				  $text{'index_file'},
			    	  $text{'index_period'},
			    	  $text{'index_post'} ], 100, 0, \@tds);
	$i = 0;
	foreach $r (@table) {
		print &ui_checked_columns_row($r, \@tds, "d",
					      $tablelogs[$i]->{'index'});
		$i++;
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}
else {
	print "<p><b>$text{'index_none'}</b><p>\n";
	print &ui_link("edit_log.cgi?new=1", $text{'index_add'});
    print "<p>\n";
	}

# Show buttons for editing global config and scheduling
print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("edit_log.cgi", $text{'index_global'},
		      $text{'index_globaldesc'},
		      &ui_hidden("global", 1));
print &ui_buttons_row("edit_sched.cgi", $text{'index_sched'},
		      $text{'index_scheddesc'});
print &ui_buttons_row("force.cgi", $text{'index_force'},
		      $text{'index_forcedesc'});
print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

