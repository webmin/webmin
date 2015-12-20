#!/usr/local/bin/perl
# index.cgi
# Display usermin configuration categories

require './usermin-lib.pl';

if (!-r "$config{'usermin_dir'}/miniserv.conf") {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	print "<p>",&text('index_econfig', "<tt>$config{'usermin_dir'}</tt>",
			  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	if ($config{'usermin_dir'} eq $standard_usermin_dir) {
		local $mode;
		if (&foreign_check("software")) {
			local %sconfig = &foreign_config("software");
			$mode = $sconfig{'package_system'} eq 'rpm' ? 'rpm' :
				$sconfig{'package_system'} eq 'dpkg' ? 'deb' :
								       undef;
			}
		print &ui_confirmation_form(
			"upgrade.cgi",
			$text{'index_install'},
			[ [ "install", 1 ],
			  [ "source", 2 ],
			  [ "mode", $mode ] ],
			[ [ undef, $mode ? $text{'index_'.$mode}
					 : $text{'index_tgz'} ] ],
			);
		}
	&ui_print_footer("/", $text{'index'});
	exit;
	}
elsif (&same_file($config{'usermin_dir'}, $config_directory)) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

	print &text('index_esame', "<tt>$config{'usermin_dir'}</tt>",
		    "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";

	&ui_print_footer("/", $text{'index'});
	exit;
	}
&get_usermin_miniserv_config(\%miniserv);
if (!$miniserv{'root'} && !-d $miniserv{'root'}) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

	print &text('index_eroot', "<tt>$config{'usermin_dir'}</tt>",
		    "<tt>$miniserv{'root'}</tt>"),"<p>\n";

	&ui_print_footer("/", $text{'index'});
	exit;
	}

$ver = &get_usermin_version();
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("usermin", "google"), undef, undef,
	&text('index_version', $ver));

@links = ( "edit_access.cgi",
	   "edit_bind.cgi",
	   "edit_ui.cgi",
	   "edit_mods.cgi",
	   "edit_os.cgi",
	   "edit_lang.cgi",
	   "edit_upgrade.cgi",
	   "edit_session.cgi",
	   "edit_assignment.cgi",
	   "edit_categories.cgi",
	   "edit_descs.cgi",
	   "edit_themes.cgi",
	   "edit_referers.cgi",
	   "edit_anon.cgi",
	   "edit_ssl.cgi",
	   "list_configs.cgi",
	   "edit_acl.cgi",
	   $ver < 0.942 ? ( ) : ( "list_restrict.cgi" ),
	   $ver < 0.76 ? ( ) : ( "edit_users.cgi",
			         "edit_defacl.cgi" ),
	   $ver < 1.164 ? ( ) : ( "edit_logout.cgi" ),
	   $ver < 1.181 ? ( ) : ( "edit_dav.cgi" ),
	   $miniserv{'session'} ? ( "list_sessions.cgi" ) : ( ),
	   "edit_blocked.cgi",
	   "edit_mobile.cgi",
	   "edit_advanced.cgi" );
@titles = map { /_(\S+).cgi/; $text{"${1}_title"} } @links;
@icons = map { /_(\S+).cgi/; "images/$1.gif" } @links;
for($i=0; $i<@links; $i++) {
	$links[$i] =~ /_(\S+).cgi/;
	$page = $1 eq "mods" ? "umods" : $1;
	if (!$access{$page}) {
		splice(@links, $i, 1);
		splice(@titles, $i, 1);
		splice(@icons, $i, 1);
		}
	}

&icons_table(\@links, \@titles, \@icons);

$init = &foreign_check("init") && $access{'bootup'};
print &ui_hr();

print &ui_buttons_start();

if ($access{'stop'}) {
	&get_usermin_miniserv_config(\%miniserv);
	if (&check_pid_file($miniserv{'pidfile'})) {
		print &ui_buttons_row("stop.cgi",
			$text{'index_stop'}, $text{'index_stopmsg'});
		}
	else {
		print &ui_buttons_row("start.cgi",
			$text{'index_start'}, $text{'index_startmsg'});
		}
	}

if ($init) {
	&foreign_require("init");
	$starting = &init::action_status("usermin");

	print &ui_buttons_row("bootup.cgi",
		$text{'index_boot'}, $text{'index_bootmsg'},
		&ui_hidden("starting", $starting),
		&ui_radio("boot", $starting == 2 ? 1 : 0,
			  [ [ 1, $text{'yes'} ],
			    [ 0, $text{'no'} ] ]));
	}

&get_usermin_miniserv_config(\%miniserv);
if (&check_pid_file($miniserv{'pidfile'})) {
	print &ui_buttons_row("restart.cgi",
		$text{'index_restart'}, $text{'index_restartmsg'});
	}

print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});
