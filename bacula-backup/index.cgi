#!/usr/local/bin/perl
# Show the Bacula main menu

require './bacula-backup-lib.pl';
$hsl = &help_search_link("bacula", "man", "doc", "google");

# Make sure it is installed
$err = &check_bacula();
if ($err) {
	&ui_print_header(undef, $module_info{'desc'}, "", "intro", 1, 1, 0,
			 $hsl);
	print &ui_config_link('index_echeck', [ $err, undef ]),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

if (&has_bacula_dir()) {
	# Test DB connection
	eval { $dbh = &connect_to_database(); };
	if ($@) {
		$err = $@;
		&ui_print_header(undef, $module_info{'desc'}, "", "intro",
				 1, 1, 0, $hsl);
		print &ui_config_link('index_edb', [ $err, undef ]),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	$dbh->disconnect();
	}

# Test node group DB
if (&has_bacula_dir() && &has_node_groups()) {
	$err = &check_node_groups();
	if ($err) {
		&ui_print_header(undef, $module_info{'desc'}, "", "intro",
				 1, 1, 0, $hsl);
		print &ui_config_link('index_eng', [ $err, undef ]),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	}

# Get the Bacula version, and check it
$ver = &get_bacula_version();
&ui_print_header(
	 undef, $module_info{'desc'}, "", "intro", 1, 1, 0,
	 $hsl, undef, undef,
	 ($ver ? &text('index_version'.$cmd_prefix, $ver)."<br>" : undef).
	 &text('index_ocmin', 'images/ocmin.gif',
	       'http://www.linmin.com/'));
if ($ver && $ver < 1.36) {
	print &text('index_eversion', 1.36, $ver),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Make sure bconsole works
if (&is_bacula_running($cmd_prefix."-dir")) {
	# Check hostname in console config
	$conconf = &get_bconsole_config();
	$condir = &find("Director", $conconf);
	$conaddr = &find_value("Address", $condir->{'members'});
	if (!&to_ipaddress($conaddr) && !&to_ip6address($conaddr)) {
		# Offer to fix hostname
		print &text('index_econsole2',
			"<tt>$console_cmd</tt>", "<tt>$conaddr</tt>"),"<p>\n";
		print &ui_form_start("fixaddr.cgi");
		print &ui_form_end([ [ "fix", $text{'index_fixaddr'} ] ]);
		&ui_print_footer("/", $text{'index'});
		exit;
		}

	# Test run bconsole
	local $status;
	eval {
		local $h = &open_console();
		$status = &console_cmd($h, "version");
		&close_console($h);
		};
	if ($status !~ /Version/i) {
		# Nope .. check if there is a password mismatch we can fix
		print &text('index_econsole',
			"<tt>$console_cmd</tt>",
			"<tt>$config{'bacula_dir'}/bconsole.conf</tt>"),"<p>\n";
		$dirconf = &get_director_config();
		$dirdir = &find("Director", $dirconf);
		$dirpass = &find_value("Password", $dirdir->{'members'});
		$conpass = &find_value("Password", $condir->{'members'});
		if ($dirpass && $conpass && $dirpass ne $conpass) {
			# Can fix!
			print &ui_form_start("fixpass.cgi");
			print &ui_form_end([ [ "fix",
					       $text{'index_fixpass'} ] ]);
			}
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	}

# Show director, storage and file daemon icons
if (&has_bacula_dir()) {
	print &ui_subheading($text{'index_dir'});
	@pages = ( "director", "clients", "filesets", "schedules",
		   "jobs", "pools", "storages" );
	&show_icons_from_pages(\@pages);
	}
if (&has_bacula_sd()) {
	print &ui_subheading($text{'index_sd'});
	@pages = ( "storagec", "devices" );
	if (!&has_bacula_dir() || $config{'showdirs'}) {
		push(@pages, "sdirectors");
		}
	&show_icons_from_pages(\@pages);
	}
if (&has_bacula_fd()) {
	print &ui_subheading($text{'index_fd'});
	@pages = ( "file" );
	if (!&has_bacula_dir() || $config{'showdirs'}) {
		push(@pages, "fdirectors");
		}
	&show_icons_from_pages(\@pages);
	}

# Show icons for node group operations
if (&has_bacula_dir() && &has_node_groups()) {
	print &ui_subheading($text{'index_groups'});
	@pages = ( "groups", "gjobs", "gbackup", "sync" );
	@links = map { "list_${_}.cgi" } @pages;
	@titles = map { $text{"${_}_title"} } @pages;
	@icons = map { "images/${_}.gif" } @pages;
	&icons_table(\@links, \@titles, \@icons);
	}

if (&has_bacula_dir()) {
	# Show icons for actions
	print &ui_hr();
	print &ui_subheading($text{'index_actions'});
	if (&is_bacula_running($cmd_prefix."-dir")) {
		@actions = ( "backup", "dirstatus", "clientstatus",
			     "storagestatus", "label", "poolstatus", "mount",
			     "restore" );
		@links = map { "${_}_form.cgi" } @actions;
		@titles = map { $text{"${_}_title"} } @actions;
		@icons = map { "images/${_}.gif" } @actions;
		&icons_table(\@links, \@titles, \@icons);
		}
	else {
		print "<b>$text{'index_notrun'}</b><p>\n";
		}
	}

print &ui_hr();

# See what processes are running
print "<b>$text{'index_status'}</b>\n";
foreach $p (@bacula_processes) {
	print "&nbsp;|&nbsp;\n" if ($p ne $bacula_processes[0]);
	print $text{'proc_'.$p}," - ";
	if (&is_bacula_running($p)) {
		print "<font color=#00aa00><b>",$text{'index_up'},
		      "</b></font>\n";
		$pcount++;
		}
	else {
		print "<font color=#ff0000><b>",$text{'index_down'},
		      "</b></font>\n";
		}
	}
print "<p>\n";
print &ui_buttons_start();
if ($pcount > 0) {
	if (!$config{'apply'}) {
		print &ui_buttons_row("apply.cgi",
			      $text{'index_apply'}, $text{'index_applydesc'});
		}
	if (&has_bacula_dir()) {
		# Only show restart button if we are running the director, as
		# for others the apply does a restart
		print &ui_buttons_row("restart.cgi",
		      $text{'index_restart'}, $text{'index_restartdesc'});
		}
	print &ui_buttons_row("stop.cgi",
		      $text{'index_stop'}, $text{'index_stopdesc'});
	}
if ($pcount < scalar(@bacula_processes)) {
	print &ui_buttons_row("start.cgi",
		      $text{'index_start'}, $text{'index_startdesc'});
	}

# See what is started at boot
if (&foreign_installed("init")) {
	&foreign_require("init", "init-lib.pl");
	$status = &init::action_status($bacula_inits[0]);
	if ($status) {
		print &ui_buttons_row("bootup.cgi",
			      $text{'index_boot'}, $text{'index_bootdesc'},
			      undef,
			      &ui_yesno_radio("boot", $status == 2 ? 1 : 0));
		}
	}

print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

sub show_icons_from_pages
{
local ($pages) = @_;
local @links = map { $_ eq "director" || $_ eq "file" || $_ eq "storagec" ?
			"edit_${_}.cgi" : "list_${_}.cgi" } @$pages;
local @titles = map { $text{"${_}_title"} } @$pages;
local @icons = map { "images/${_}.gif" } @$pages;
&icons_table(\@links, \@titles, \@icons);
}

