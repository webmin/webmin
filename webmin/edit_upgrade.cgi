#!/usr/local/bin/perl
# edit_upgrade.cgi
# Display a form for upgrading all of webmin from a tarfile

require './webmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'upgrade_title'}, "");

if (&shared_root_directory()) {
	&ui_print_endpage($text{'upgrade_eroot'});
	}

# what kind of install was this?
$mode = &get_install_type();

# was the install to a target directory?
if (open(DIR, "$config_directory/install-dir")) {
	chop($dir = <DIR>);
	close(DIR);
	}
if ($mode eq "solaris-pkg") {
	$skip_upgrade = $text{'upgrade_esolaris'};
	}
elsif ($mode eq "zip") {
	$skip_upgrade = $text{'upgrade_ezip'};
	}
elsif ($mode eq "portage") {
	$skip_upgrade = $text{'upgrade_eportage'};
	}

# Show tabs
@tabs = map { [ $_, $text{'upgrade_tab'.$_}, "edit_upgrade.cgi?mode=$_" ] }
	    ( $skip_upgrade ? ( ) : ( "upgrade" ),
	      "grants", "update", "sched" );
print ui_tabs_start(\@tabs, "mode", $in{'mode'} || $tabs[0]->[0], 1);

if (!$skip_upgrade) {
	# Display upgrade form
	print ui_tabs_start_tab("mode", "upgrade");
	print $text{"upgrade_desc$mode"},"<p>";

	print ui_form_start("upgrade.cgi", "form-data");
	print ui_hidden("mode", $mode);
	print ui_hidden("dir", $dir);
	print ui_table_start($text{'upgrade_title'}, undef, 1);

	@opts = ( [ 0, $text{'upgrade_local'},
		    &ui_filebox("file", undef, 60) ],
		  [ 1, $text{'upgrade_uploaded'},
		    &ui_upload("file") ],
		  [ 5, $text{'upgrade_url'},
		    &ui_textbox("url", undef, 60) ] );
	if ($mode eq "gentoo") {
		push(@opts, [ 4, $text{'upgrade_emerge'} ]);
		}
	elsif ($mode ne "sun-pkg") {
		push(@opts, [ 2, $text{'upgrade_ftp'} ]);
		}
	print &ui_table_row($text{'upgrade_src'},
		&ui_radio_table("source", $opts[$#opts]->[0], \@opts));

	@cbs = ( );
	if (!$mode && !$dir) {
		# Checkbox to delete original directory
		push(@cbs, &ui_checkbox("delete", 1, $text{'upgrade_delete'},
					$gconfig{'upgrade_delete'}));
		}
	if ((!$mode || $mode eq "rpm") && &foreign_check("proc")) {
		# Checkbox to check signature
		($ec, $emsg) = &gnupg_setup();
		push(@cbs, &ui_checkbox("sig", 1, $text{'upgrade_sig'}, $ec));
		}
	if (!$mode) {
		# Checkbox to not install missing modules
		push(@cbs, &ui_checkbox("only", 1, $text{'upgrade_only'},
					-r "$root_directory/minimal-install"));
		}
	push(@cbs, &ui_checkbox("force", 1, $text{'upgrade_force'}, 0));
	if ($main::session_id) {
		# Checkbox to disconnect other sessions
		push(@cbs, &ui_checkbox("disc", 1, $text{'upgrade_disc'}, 0));
		}
	print &ui_table_row($text{'upgrade_opts'},
			    join("<br>\n", @cbs));
	print ui_table_end();
	print &ui_form_end([ [ undef, $text{'upgrade_ok'} ] ]);
	print ui_tabs_end_tab();
	}

# Display new module grants form
print ui_tabs_start_tab("mode", "grants");
print "$text{'newmod_desc'}<p>\n";
print ui_form_start("save_newmod.cgi", "post");
print ui_table_start($text{'newmod_header'});

$newmod = &get_newmodule_users();
print &ui_table_row(undef,
	&ui_opt_textbox("newmod", $newmod ? join(" ", @$newmod) : "", 60,
			$text{'newmod_def'}."<br>\n",
			$text{'newmod_users'}), 2);

print ui_table_end();
print ui_form_end([ [ undef, $text{'save'} ] ]);
print ui_tabs_end_tab();

# Display module update form
print ui_tabs_start_tab("mode", "update");
print "$text{'update_desc1'}<p>\n";
print ui_form_start("update.cgi", "post");
print ui_table_start($text{'update_header1'}, undef, 2);

print &ui_table_row($text{'update_src'},
	&ui_radio("source", $config{'upsource'} ? 1 : 0,
		  [ [ 0, $text{'update_webmin'}."<br>" ],
		    [ 1, $text{'update_other'} ] ])."<br>\n".
	&ui_textarea("other", join("\n", split(/\t+/, $config{'upsource'})),
		     2, 50));

print &ui_table_row($text{'update_opts'},
	&ui_checkbox("show", 1, $text{'update_show'},
		     $config{'upshow'}).
	"<br>\n".
	&ui_checkbox("missing", 1, $text{'update_missing'},
	             $config{'upmissing'}).
	"<br>\n".
	&ui_checkbox("third", 1, $text{'update_third'},
		     $config{'upthird'}).
	"<br>\n".
	&ui_checkbox("checksig", 1, $text{'update_checksig'},
		     $config{'upchecksig'}));

print &ui_table_row($text{'update_user'},
	&ui_textbox("upuser", $config{'upuser'}, 30));
print &ui_table_row($text{'update_pass'},
	&ui_password("uppass", $config{'uppass'}, 30));

print ui_table_end();
print ui_form_end([ [ undef, $text{'update_ok'} ] ]);
print ui_tabs_end_tab();

# Display scheduled update form
print ui_tabs_start_tab("mode", "sched");
print "$text{'update_desc2'}<p>\n";
print ui_form_start("update_sched.cgi", "post");
print ui_table_start($text{'update_header2'}, undef, 2);

print &ui_table_row($text{'update_enabled'},
	&ui_yesno_radio("enabled", $config{'update'}));

print &ui_table_row($text{'update_src'},
	&ui_radio("source", $config{'upsource'} ? 1 : 0,
		  [ [ 0, $text{'update_webmin'}."<br>" ],
		    [ 1, $text{'update_other'} ] ])."<br>\n".
	&ui_textarea("other", join("\n", split(/\t+/, $config{'upsource'})),
		     2, 50));

if ($config{'cron_mode'} == 0) {
	$upmins = sprintf "%2.2d", $config{'upmins'};
	print &ui_table_row("", 
		&text('update_sched2',
		      &ui_textbox("hour", $config{'uphour'}, 2),
		      &ui_textbox("mins", $upmins, 2),
		      &ui_textbox("days", $config{'updays'}, 3)));
	}
else {
	&foreign_require("cron", "cron-lib.pl");
	@jobs = &cron::list_cron_jobs();
	$job = &find_cron_job(\@jobs);
	$job ||= { 'mins' => 0,
		   'hours' => $config{'uphour'},
		   'days' => "*/$config{'updays'}",
		   'months' => '*',
		   'weekdays' => '*' };
	print &cron::get_times_input($job, 1);
	}

print &ui_table_row($text{'update_opts'},
	&ui_checkbox("show", 1, $text{'update_show'},
		     $config{'upshow'}).
	"<br>\n".
	&ui_checkbox("missing", 1, $text{'update_missing'},
	             $config{'upmissing'}).
	"<br>\n".
	&ui_checkbox("third", 1, $text{'update_third'},
		     $config{'upthird'}).
	"<br>\n".
	&ui_checkbox("quiet", 1, $text{'update_quiet'},
		     $config{'upquiet'}).
	"<br>\n".
	&ui_checkbox("checksig", 1, $text{'update_checksig'},
		     $config{'upchecksig'}));

print &ui_table_row($text{'update_email'},
	&ui_textbox("upemail", $config{'upemail'}, 30));
print &ui_table_row($text{'update_user'},
	&ui_textbox("upuser", $config{'upuser'}, 30));
print &ui_table_row($text{'update_pass'},
	&ui_password("uppass", $config{'uppass'}, 30));

print ui_table_end();
print ui_form_end([ [ undef, $text{'update_apply'} ] ]);
print ui_tabs_end_tab();

print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});

