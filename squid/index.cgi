#!/usr/local/bin/perl
# index.cgi
# Display a menu of different kinds of options

use strict;
use warnings;
require './squid-lib.pl';
our (%in, %text, %config, %access, $module_name, $module_config_directory);

# Check for the squid executable
if (!&has_command($config{'squid_path'})) {
	&ui_print_header(undef, $text{'index_header'}, "", undef, 1, 1);
	print &text('index_msgnoexe',$config{'squid_path'},
		$module_name),"<p>\n";

	&foreign_require("software", "software-lib.pl");
	my $lnk = &software::missing_install_link("squid", $text{'index_squid'},
			"../$module_name/", $text{'index_header'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{'index_return'});
	exit;
	}

# Check for squid config file
if (!-r $config{'squid_conf'}) {
	&ui_print_header(undef, $text{'index_header'}, "", undef, 1, 1);
	print &text('index_msgnoconfig',$config{'squid_conf'},
		$module_name);
	print "\n<p>\n";
	&ui_print_footer("/", $text{'index_return'});
	exit;
	}

# Check the version number
my $ver = &backquote_command("$config{'squid_path'} -v 2>&1");
my $fullver = $ver;
if ($ver =~ /LUSCA/) {
	# Special Squid variant, actually equivalent to 2.7
	$ver = "Squid Cache: Version 2.7.STABLE.LUSCA.2012";
	}
if ($ver =~ /version\s+(\S+)/i) {
	$ver = $1;
	}
my $squid_version;
if ($ver =~ /^(1\.1)\.\d+/ || $ver =~ /^(1)\.NOVM/ ||
    $ver =~ /^([2-4]\.[0-9]+)\./) {
	# Save version number
	open(VERSION, ">$module_config_directory/version");
	print VERSION $1,"\n";
	close(VERSION);
	$squid_version = $1;
	}
else {
	&ui_print_header(undef, $text{'index_header'}, "", undef, 1, 1);
	print &text('index_msgnosupported2', "<tt>1.1</tt>", "<tt>3.4</tt>"),
	      "<p>\n";
	print &text('index_squidver', "$config{'squid_path'} -v"),"\n";
	print "<pre>$fullver</pre>\n";
	&ui_print_footer("/", $text{'index_return'});
	exit;
	}

# Check for the cache directory
my $conf = &get_config();
my @caches;
if (!&check_cache($conf, \@caches, 1)) {
	&ui_print_header(undef, $text{'index_header'}, "", undef, 1, 1);
	print "<center>\n";
	if (@caches > 1) {
		print &text('index_msgnodir1', join(", ", @caches));
		}
	else {
		print &text('index_msgnodir2', $caches[0]);
		}
	print $text{'index_msgnodir3'},"<br>\n";
	print &ui_form_start("init_cache.cgi");
	print &ui_submit($text{'index_buttinit'});
	my $def = defined(getpwnam("squid")) ? "squid" :
		  defined(getpwnam("proxy")) ? "proxy" :
		  defined(getpwnam("httpd")) ? "httpd" : undef;
	if (!&find_config("cache_effective_user", $conf)) {
		print $text{'index_asuser'}," ",&unix_user_input("user", $def),
			"<p>\n";
		}
	else {
		print "<input type=hidden name=nouser value=1>\n";
		}
	print &ui_hidden("caches", join(" ",@caches));
	print &ui_form_end();
	print "</center>\n";
	print &ui_hr();
	}
else {
	&ui_print_header(undef, $text{'index_header'}, "", "intro",
		1, 1, 0, &restart_button()."<br>".
			 &help_search_link("squid", "doc", "google"),
		undef, undef, &text('index_version', $squid_version));
	}

# Check if authentication is setup
my $auth;
if ($squid_version >= 2) {
	my $file = &get_auth_file($conf);
	$auth = 1 if ($file);
	}

my $calamaris = &has_command($config{'calamaris'});
my $delay = $squid_version >= 2.3;
my $authparam = $squid_version >= 2;
my $headeracc = $squid_version >= 2.5;
my $iptables = &foreign_check("firewall");

my @otitles = ( 'portsnets', 'othercaches', 'musage', 'logging',
	        'copts', 'hprogs', 'actrl', 'admopts',
	        ( $auth ? ( 'proxyauth' ) : ( ) ),
	        ( $authparam ? ( 'authparam' ) : ( ) ),
	        ( $delay ? ( 'delay' ) : ( ) ),
	        ( $headeracc ? ( 'headeracc' ) : ( ) ),
	        'refresh',
	        'miscopt',
	        ( $iptables ? ( 'iptables' ) : ( ) ),
	        'cms', 'cachemgr', 'rebuild',
	        ( $calamaris ? ( 'calamaris' ) : ( ) ),
		'manual' );
my @olinks =  ( "edit_ports.cgi", "edit_icp.cgi", "edit_mem.cgi",
	        "edit_logs.cgi", "edit_cache.cgi", "edit_progs.cgi",
	        "edit_acl.cgi", "edit_admin.cgi",
	        ( $auth ? ( "edit_nauth.cgi" ) : ( ) ),
	        ( $authparam ? ( "edit_authparam.cgi" ) : ( ) ),
	        ( $delay ? ( 'edit_delay.cgi' ) : ( ) ),
	        ( $headeracc ? ( 'list_headeracc.cgi' ) : ( ) ),
	        "list_refresh.cgi",
	        "edit_misc.cgi",
	        ( $iptables ? ( "edit_iptables.cgi" ) : ( ) ),
	        "cachemgr.cgi", "edit_cachemgr.cgi", "clear.cgi",
	        ( $calamaris ? ( "calamaris.cgi" ) : ( ) ),
	        "edit_manual.cgi" );
for(my $i=0; $i<@otitles; $i++) {
	if (!$access{$otitles[$i]}) {
		splice(@otitles, $i, 1);
		splice(@olinks, $i, 1);
		$i--;
		}
	else {
		$otitles[$i] = $text{'index_'.$otitles[$i]};
		}
	}
my @oicons = map { my $t = $_;
		   $t =~ s/cgi/gif/;
		   $t =~ s/edit_// if ($t ne 'edit_cachemgr.gif');
		   "images/$t" } @olinks;
&icons_table(\@olinks, \@otitles, \@oicons);

# Show start/stop/apply buttons
if ($config{'restart_pos'} != 1) {
	print &ui_hr();
	print &ui_buttons_start();
	if (my $pid = &is_squid_running()) {
		if ($access{'restart'}) {
			print &ui_buttons_row("restart.cgi",
					      $text{'index_restart'},
					      $text{'index_restartdesc'},
					      &ui_hidden("redir", "index.cgi"));
			}
		if ($access{'start'}) {
			print &ui_buttons_row("stop.cgi", $text{'index_stop'},
					      $text{'index_stopdesc'},
					      &ui_hidden("redir", "index.cgi"));
			}
		}
	else {
		if ($access{'start'}) {
			print &ui_buttons_row("start.cgi", $text{'index_start'},
					      $text{'index_startdesc'},
					      &ui_hidden("redir", "index.cgi"));
			}
		}
	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index_return'});

