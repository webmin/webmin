#!/usr/local/bin/perl
# index.cgi
# Display a table of icons for different types of webmin configuration

use strict;
use warnings;
require './webmin-lib.pl';
our (%in, %text, %gconfig, %config);
my $ver = &get_webmin_version();
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	undef, undef, undef, &text('index_version', $ver));
my %access = &get_module_acl();
&ReadParse();

my (@wlinks, @wtitles, @wicons);
@wlinks = ( "edit_access.cgi", "edit_bind.cgi", "edit_log.cgi",
	    "edit_proxy.cgi", "edit_ui.cgi", "edit_mods.cgi",
	    "edit_os.cgi", "edit_lang.cgi", "edit_startpage.cgi",
	    "edit_upgrade.cgi", "edit_session.cgi", "edit_twofactor.cgi",
	    "edit_assignment.cgi",
	    "edit_categories.cgi", "edit_descs.cgi", "edit_themes.cgi",
	    "edit_referers.cgi", "edit_anon.cgi", "edit_lock.cgi",
	    "edit_mobile.cgi", "edit_blocked.cgi", "edit_status.cgi",
            "edit_advanced.cgi", "edit_debug.cgi", "edit_web.cgi",
	    "edit_webmincron.cgi", );
@wtitles = ( $text{'access_title'}, $text{'bind_title'},
	     $text{'log_title'}, $text{'proxy_title'},
	     $text{'ui_title'}, $text{'mods_title'},
	     $text{'os_title'}, $text{'lang_title'},
	     $text{'startpage_title'}, $text{'upgrade_title'},
	     $text{'session_title'}, $text{'twofactor_title'},
             $text{'assignment_title'},
	     $text{'categories_title'}, $text{'descs_title'},
	     $text{'themes_title'}, $text{'referers_title'},
	     $text{'anon_title'}, $text{'lock_title'},
	     $text{'mobile_title'}, $text{'blocked_title'},
	     $text{'status_title'}, $text{'advanced_title'},
	     $text{'debug_title'}, $text{'web_title'},
	     $text{'webmincron_title'}, );
@wicons = ( "images/access.gif", "images/bind.gif", "images/log.gif",
	    "images/proxy.gif", "images/ui.gif", "images/mods.gif",
	    "images/os.gif", "images/lang.gif", "images/startpage.gif",
            "images/upgrade.gif", "images/session.gif", "images/twofactor.gif",
	    "images/assignment.gif", "images/categories.gif",
	    "images/descs.gif", "images/themes.gif", "images/referers.gif",
	    "images/anon.gif", "images/lock.gif", "images/mobile.gif",
	    "images/blocked.gif", "images/status.gif",
	    "images/advanced.gif", "images/debug.gif", "images/web.gif",
	    "images/webmincron.gif", );
if (&foreign_check("mailboxes")) {
	push(@wlinks, "edit_sendmail.cgi");
	push(@wtitles, $text{'sendmail_title'});
	push(@wicons, "images/sendmail.gif");
	}
push(@wlinks, "edit_ssl.cgi", "edit_ca.cgi");
push(@wtitles, $text{'ssl_title'}, $text{'ca_title'});
push(@wicons, "images/ssl.gif", "images/ca.gif");

# Hide dis-allowed pages
my %allow = map { $_, 1 } split(/\s+/, $access{'allow'});
my %disallow = map { $_, 1 } split(/\s+/, $access{'disallow'});
for(my $i=0; $i<@wlinks; $i++) {
	$wlinks[$i] =~ /edit_(\S+)\.cgi/;
	if (%allow && !$allow{$1} ||
	    $disallow{$1} ||
	    $1 eq "webmin" && $gconfig{'os_type'} eq 'windows') {
		splice(@wlinks, $i, 1);
		splice(@wtitles, $i, 1);
		splice(@wicons, $i, 1);
		$i--;
		}
	}
&icons_table(\@wlinks, \@wtitles, \@wicons);

print &ui_hr();

print &ui_buttons_start();

my %miniserv;
&get_miniserv_config(\%miniserv);

if (&foreign_check("init")) {
	&foreign_require("init");
	my $starting = &init::action_status("webmin");
	print &ui_buttons_row("bootup.cgi",
	      $text{'index_boot'},
	      $text{'index_bootmsg'}.
	      ($miniserv{'inetd'} ? "<b>$text{'index_inetd'}</b>" :
	       !$ENV{'MINISERV_CONFIG'} ? "<b>$text{'index_apache'}</b>" : ""),
	      &ui_hidden("starting", $starting),
	      &ui_radio("boot", $starting == 2 ? 1 : 0,
			[ [ 1, $text{'yes'} ],
			  [ 0, $text{'no'} ] ]));
	}

# Restart Webmin
if (!$miniserv{'inetd'} && $ENV{'MINISERV_CONFIG'}) {
	print &ui_buttons_row("restart.cgi",
		      $text{'index_restart'}, $text{'index_restartmsg'});
	}

# Refresh modules
print &ui_buttons_row("refresh_modules.cgi",
	      $text{'index_refresh'}, $text{'index_refreshmsg'});

print &ui_buttons_end();

if ($in{'refresh'} && defined(&theme_post_change_modules)) {
	# Refresh left menu
	&theme_post_change_modules();
	}

&ui_print_footer("/", $text{'index'});

