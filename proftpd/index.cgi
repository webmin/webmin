#!/usr/local/bin/perl
# index.cgi
# Display the icons for various types of proftpd config options

require './proftpd-lib.pl';

# Check if proftpd is installed
if (!&has_command($config{'proftpd_path'})) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("proftpd", "man", "doc", "google"));
	print &text('index_eproftpd', "<tt>$config{'proftpd_path'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";

	&foreign_require("software", "software-lib.pl");
	$lnk = &software::missing_install_link("proftpd",$text{'index_proftpd'},
			"../$module_name/", $text{'index_title'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{'index'});
	return;
	}

# Check that the command is actually proftpd
if (!$site{'version'}) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("proftpd", "man", "doc", "google"));
	print &text('index_eproftpd2',
		  "<tt>$config{'proftpd_path'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name",
		  "<tt>$config{'proftpd_path'} -v</tt>",
		  "<pre>$out</pre>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	return;
	}

# Check if the config file exists
$conf = &get_config();
if (!@$conf) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("proftpd", "man", "doc", "google"));
	print &text('index_econf', "<tt>$config{'proftpd_conf'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	return;
	}

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("proftpd", "man", "doc", "google"),
	undef, undef, &text('index_version', $site{'fullversion'}));
$conf = &get_config();

# Display global category icons
print &ui_subheading($text{'index_global'});
$ft_icon = { "icon" => "images/dir.gif",
	     "name" => $text{'ftpaccess_title'},
	     "link" => "ftpaccess.cgi" };
$us_icon = { "icon" => "images/ftpusers.gif",
	     "name" => $text{'ftpusers_title'},
	     "link" => "edit_ftpusers.cgi" };
$ed_icon = { "icon" => "images/edit.gif",
	     "name" => $text{'manual_configs'},
	     "link" => "allmanual_form.cgi" };
&config_icons("root global", "edit_global.cgi?", $ft_icon, $us_icon, $ed_icon);

# Display global per-directory/limit options
$global = &find_directive_struct("Global", $conf);
$gconf = $global->{'members'} if ($global);
@dir = ( &find_directive_struct("Directory", $gconf) ,
	 &find_directive_struct("Limit", $gconf) );
if (@dir) {
	print &ui_hr();
	print &ui_subheading($text{'virt_header'});
	foreach $d (@dir) {
		if ($d->{'name'} eq 'Limit') {
			push(@links, "limit_index.cgi?limit=".
				     &indexof($d, @$gconf)."&global=1");
			push(@titles, &text('virt_limit', $d->{'value'}));
			push(@icons, "images/limit.gif");
			}
		else {
			push(@links, "dir_index.cgi?idx=".
				     &indexof($d, @$gconf)."&global=1");
			push(@titles, &text('virt_dir', $d->{'value'}));
			push(@icons, "images/dir.gif");
			}
		}
	&icons_table(\@links, \@titles, \@icons, 3);
	}
print "<p>\n";

print &ui_form_start("create_dirlimit.cgi", "post");
print &ui_hidden("global", 1);
print &ui_table_start($text{'index_dlheader'}, undef, 2);

print &ui_table_row($text{'index_dlmode'},
	&ui_radio_table("mode", 0,
		[ [ 0, $text{'virt_path'},
		    &ui_textbox("dir", undef, 50) ],
		  [ 1, $text{'virt_cmds'},
		    &ui_textbox("cmd", undef, 30) ] ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

# Start virtual server list with default
push(@vname, $text{'index_defserv'});
push(@vlink, "virt_index.cgi");
push(@vdesc, $text{'index_defdesc'});
push(@vaddr, $text{'index_any'});
push(@vserv, &def(&find_directive("ServerName", $conf), $text{'default'}));

# Add other virtual servers
@virt = &find_directive_struct("VirtualHost", $conf);
foreach $v (@virt) {
	$vm = $v->{'members'};
	push(@vname, $text{'index_virt'});
	push(@vlink, "virt_index.cgi?virt=".&indexof($v, @$conf));
	push(@vaddr, $v->{'value'});
	$sname = &find_directive("ServerName", $vm);
	local $ip = &to_ipaddress($v->{'value'});
	push(@vdesc, &text('index_vdesc', $ip ? $ip : $text{'index_eip'}));
	push(@vserv, &def(&find_vdirective("ServerName", $vm, $conf),
			  $text{'index_auto'}));
	}

# Show virtual servers
print &ui_hr();
print &ui_subheading($text{'index_virts'});

if ($config{'show_list'} && scalar(@vname)) {
	# as list for people with lots of servers
	print &ui_columns_start([ $text{'index_type'},
				  $text{'index_addr'},
				  $text{'index_name'} ], 100, 0);
	for($i=0; $i<@vname; $i++) {
		print &ui_columns_row([
			&ui_link($vlink[$i], &html_escape($vname[$i])),
			&html_escape($vaddr[$i]),
			&html_escape($vserv[$i]),
			]);
		}
	print &ui_columns_end();
	}
else {
	# as icons for niceness
	# XXX fix this
	print "<table width=100% cellpadding=5>\n";
	for($i=0; $i<@vname; $i++) {
		print "<tr> <td valign=top align=center nowrap>";
		print '<div class="row icons-row inline-row">';
		&generate_icon("images/virt.gif", &html_escape($vname[$i]),
			       $vlink[$i]);
		print "</div>\n";
		print "</td> <td valign=top>\n";
		print &html_escape($vdesc[$i]),"<br>\n";
		print "<table width=100%><tr>\n";
		print "<td width=30%><b>$text{'index_addr'}</b> ",
		      &html_escape($vaddr[$i]),"</td>\n";
		print "<td width=70%><b>$text{'index_name'}</b> ",
		      &html_escape($vserv[$i]),"</td></tr>\n";
		print "</table></td> </tr>\n";
		}
	print "</table>\n";
	}
print "<p>\n";

# Form to create a virtual FTP server
print &ui_form_start("create_virt.cgi", "post");
print &ui_table_start($text{'index_create'}, undef, 2);

print &ui_table_row($text{'index_addr'},
	&ui_textbox("addr", undef, 25));

print &ui_table_row($text{'index_port'},
	&opt_input(undef, "Port", $text{'default'}, 6));

print &ui_table_row($text{'index_name'},
	&opt_input(undef, "ServerName", $text{'default'}, 25));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

# Find out how ProFTPd is running
($inet, $inet_mod) = &running_under_inetd();
if (!$inet) {
	# Get the FTP server pid
	$pid = &get_proftpd_pid();
	print &ui_hr();
	print &ui_buttons_start();
	}
if (!$inet && $pid) {
	print &ui_buttons_row("apply.cgi",
			      $text{'index_apply'},
			      $site{'version'} > 1.22 ? 
				$text{'index_applymsg2'} :
				$text{'index_applymsg'});
	print &ui_buttons_row("stop.cgi",
			      $text{'index_stop'}, $text{'index_stopmsg'});
	}
elsif (!$inet && !$pid) {
	print &ui_buttons_row("start.cgi",
		      $text{'index_start'},
		      $inet_mod ? &text('index_startmsg', "/$inet_mod/")
				: $text{'index_startmsg2'});
	}
if (!$inet) {
	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});

