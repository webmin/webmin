#!/usr/local/bin/perl
# Update, reboot or delete a zone

require './zones-lib.pl';
do 'forms-lib.pl';
&ReadParse();
$zinfo = &get_zone($in{'zone'});
$zinfo || &error($text{'edit_egone'});

if ($in{'reboot'}) {
	# Reboot after asking for confirmation
	$p = &get_confirm_page(\%in, "reboot", $zinfo, $in{'list'});
	if ($p->get_confirm()) {
		# Do it
		$p = &get_execute_page("reboot", $zinfo, $in{'list'});
		$p->print();
		}
	elsif ($p->get_cancel()) {
		# Cancelled
		&redirect($p->get_footer(0));
		}
	else {
		$p->print();
		}
	}
elsif ($in{'boot'}) {
	# Just bootup now
	$p = &get_execute_page("boot", $zinfo, $in{'list'});
	$p->print();
	}
elsif ($in{'halt'}) {
	# Shutdown after asking for confirmation
	$p = &get_confirm_page(\%in, "halt", $zinfo, $in{'list'});
	if ($p->get_confirm()) {
		# Do it
		$p = &get_execute_page("halt", $zinfo, $in{'list'});
		$p->print();
		}
	elsif ($p->get_cancel()) {
		# Cancelled
		&redirect($p->get_footer(0));
		}
	else {
		$p->print();
		}
	}
elsif ($in{'install'}) {
	# Install system now
	$p = new WebminUI::Page(&zone_title($zinfo->{'name'}), $text{'install_title'});
	$d = new WebminUI::DynamicText(\&execute_install);
	$p->add_form($d);
	$d->set_message($text{'install_doing'});
	$d->set_wait(1);
	if ($in{'list'}) {
		$p->add_footer("index.cgi", $text{'index_return'});
		}
	else {
		$p->add_footer("edit_zone.cgi?zone=$zinfo->{'name'}",
			       $text{'edit_return'});
		}
	$p->print();
	}
elsif ($in{'delete'}) {
	# Delete after confirming
	$p = &get_confirm_page(\%in, "delete", $zinfo, $in{'list'});
	if ($p->get_confirm()) {
		# Do it
		$p = &get_execute_page("delete", $zinfo, $in{'list'});
		$p->print();
		}
	elsif ($p->get_cancel()) {
		# Cancelled
		&redirect($p->get_footer(0));
		}
	else {
		$p->print();
		}
	}
elsif ($in{'uninstall'}) {
	# Un-install after confirming
	$p = &get_confirm_page(\%in, "uninstall", $zinfo, $in{'list'});
	if ($p->get_confirm()) {
		# Do it
		$p = &get_execute_page("uninstall", $zinfo, $in{'list'}, "-F");
		$p->print();
		}
	elsif ($p->get_cancel()) {
		# Cancelled
		&redirect($p->get_footer(0));
		}
	else {
		$p->print();
		}
	}
elsif ($in{'wupgrade'} || $in{'winstall'}) {
	# Install Webmin now
	$p = new WebminUI::Page(&zone_title($in{'zone'}), $text{'webmin_title'});
	$d = new WebminUI::DynamicText(\&execute_webmin);
	$p->add_form($d);
	$d->set_message($text{'create_webmining'});
	$d->set_wait(1);
	$p->add_footer("edit_zone.cgi?zone=$zinfo->{'name'}",
		       $text{'edit_return'});
	$p->print();
	}
elsif ($in{'webmin'}) {
	# Redirect to Webmin in the zone
	$url = &zone_running_webmin($zinfo);
	&error($text{'save_ewebmin'}) if (!$url);
	&redirect($url);
	}
else {
	# Just update autoboot and pool
	$gform = &get_zone_form(\%in, $zinfo);
	$gform->validate_redirect("edit_zone.cgi");
	&set_zone_variable($zinfo, "autoboot", $gform->get_value('autoboot'));
	&set_zone_variable($zinfo, "pool", $gform->get_value('pool'));
	&webmin_log("save", "zone", $in{'zone'});
	&redirect("");
	}

# execute_install(&dynamic)
sub execute_install
{
my ($d) = @_;
local $ok = &callback_zone_command($zinfo, "install",
				   \&WebminUI::DynamicText::add_line, [ $d ]);
if ($ok) {
	$p->add_message($text{'create_done'});
	$sysidcfg = &zone_sysidcfg_file($in{'zone'});
	if (-r $sysidcfg) {
		# Copy sysidcfg into place, for later boot
		# We Copy instead of Move just incase we
		# uninstall the zone but want to reinstall it
		# at a later time.
		&system_logged("cp $sysidcfg $zinfo->{'zonepath'}/root/etc/sysidcfg");
		}
	&config_zone_nfs($zinfo);
	&webmin_log("install", "zone", $in{'zone'});
	}
else {
	$p->add_error($text{'create_failed'});
	}
}

sub execute_webmin
{
my ($d) = @_;
$script = &get_zone_root($zinfo)."/tmp/install-webmin";
$err = &create_webmin_install_script($zinfo, $script);
if ($err) {
	$p->add_error(&text('created_wfailed', $err));
	}
else {
	$ex = &run_in_zone_callback($zinfo, "/tmp/install-webmin",
			      \&WebminUI::DynamicText::add_line, [ $d ]);
	if (!$ex) {
		$p->add_message($text{'create_done'});
		&post_webmin_install($zinfo);
		}
	else {
		$p->add_error($text{'create_failed'});
		}
	}
}

