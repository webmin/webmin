#!/usr/local/bin/perl
# index.cgi
# Display existing IPsec tunnels

require './ipsec-lib.pl';

# Make sure the ipsec command exists
if (!&has_command($config{'ipsec'}) ||
    !(($ipsec_version, $ipsec_program) = &get_ipsec_version(\$out))) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		&help_search_link("freeswan", "doc", "google"));
	print "<p>",&text('index_eipsec', "<tt>$config{'ipsec'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	if ($out) {
		print &text('index_out',
			    "<tt>$config{'ipsec'} --version</tt>"),"\n";
		print "<pre>$out</pre>\n";
		}
	}
else {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		&help_search_link("freeswan", "doc", "google"), undef, undef,
		&text('index_version2', $ipsec_version, $ipsec_program));

	# Make sure the config file exists
	if (!-r $config{'file'}) {
		print "<p>",&text('index_econfig', "<tt>$config{'file'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
		}
	else {
		# Check for the host secret
		if (!&got_secret()) {
			# No key setup yet .. offer to create one
			print "<p><b>",&text('index_nokey',
				  "<tt>$config{'secrets'}</tt>"),"</b><br>\n";
			print "<center><form action=newkey.cgi>\n";
			print "<input type=submit ",
			      "value='$text{'index_newkey'}'>\n";
			printf "<input name=host size=20 value='%s'>\n",
				&get_system_hostname();
			print "</form></center>\n";
			}
		else {
			# Show icons for connections
			print &ui_subheading($text{'index_header1'});
			@conf = &get_config();
			@conns = grep { $_->{'name'} eq 'conn' } @conf;
			if (@conns) {
				foreach $c (@conns) {
					push(@links, "edit.cgi?idx=".
						     $c->{'index'});
					if ($c->{'value'} eq '%default') {
						push(@titles, "<i>$text{'index_defconn'}</i>");
						$has_default++;
						}
					else {
						push(@titles,
						    &text('index_conn',
						    "<tt>$c->{'value'}</tt>"));
						push(@start, $c->{'value'});
						}
					push(@icons, "images/conn.gif");
					}
				&icons_table(\@links, \@titles, \@icons);
				}
			else {
				print "<b>$text{'index_none'}</b><p>\n";
				}
			print &ui_link("edit.cgi?new=1",$text{'index_add'});
			if (!$has_default) {
				print "&nbsp;" x 3;
				print &ui_link("edit.cgi?new=2",$text{'index_adddef'});
				}
			print "&nbsp;" x 3;
			print "<a href=import_form.cgi>$text{'index_import'}</a>";
			print "<p>\n";

			# Show icons for various options
			print &ui_hr();
			print &ui_subheading($text{'index_header2'});
			@links = ( "edit_config.cgi", "showkey.cgi",
				   "list_secrets.cgi" );
			@titles = ( $text{'config_title'},
				    $text{'showkey_title'},
				    $text{'secrets_title'} );
			@icons = ( "images/config.gif", "images/showkey.gif",
				   "images/secrets.gif" );
			if ($ipsec_version =~ /(\d+)/ && $1 >= 2) {
				@policies = &list_policies();
				foreach $p (@policies) {
					push(@links, "edit_policy.cgi?policy=$p");
					push(@titles, $text{'policy_desc_'.$p} ||
						      &text('policy_desc', $p));
					push(@icons, "images/policy.gif");
					}
				$got_policies = 1;
				}
			&icons_table(\@links, \@titles, \@icons, 4);
			if (!@policies && $got_policies) {
				print "<b>",&text('index_nopol',
					"$gconfig{'webprefix'}/config.cgi?$module_name"),"</b><p>\n";
				}

			print &ui_hr();
			print "<table width=100%>\n";

			# Start connection button
			if (@start && &is_ipsec_running()) {
				print "<form action=up.cgi>\n";
				print "<td><input type=submit ",
				      "value='$text{'index_up'}'>\n";
				print "<select name=conn>\n";
				foreach $s (@start) {
					printf "<option %s>%s</option>\n",
					    $config{'conn'} eq $s ? "selected"
								  : "", $s;
					}
				print "</select></td>\n";
				print "<td>$text{'index_updesc'}</td>\n";
				print "</tr></form>\n";
				}

			# Start/stop/restart ipsec buttons
			if (&is_ipsec_running()) {
				print "<form action=restart.cgi><tr>\n";
				print "<td><input type=submit ",
				      "value='$text{'index_restart'}'></td>\n";
				print "<td>$text{'index_restartdesc'}</td>\n";
				print "</tr></form>\n";

				print "<form action=stop.cgi><tr>\n";
				print "<td><input type=submit ",
				      "value='$text{'index_stop'}'></td>\n";
				print "<td>$text{'index_stopdesc'}</td>\n";
				print "</tr></form>\n";
				}
			else {
				print "<form action=start.cgi><tr>\n";
				print "<td><input type=submit ",
				      "value='$text{'index_start'}'></td>\n";
				print "<td>$text{'index_startdesc'}</td>\n";
				print "</tr></form>\n";
				}

			# Show boot-time start button
			if (&foreign_check("init")) {
			    	&foreign_require("init", "init-lib.pl");
				$starting = &init::action_status("ipsec");
				print "<form action=bootup.cgi>\n";
				print "<input type=hidden name=starting ",
				      "value='$starting'>\n";
				print "<td nowrap><input type=submit ",
				      "value='$text{'index_boot'}'>\n";
				printf "<input type=radio name=boot ".
				       "value=1 %s> %s\n",
					$starting == 2 ? "checked" : "",
					$text{'yes'};
				printf "<input type=radio name=boot ".
				       "value=0 %s> %s</td>\n",
					$starting == 2 ? "" : "checked",
					$text{'no'};
				print "<td>$text{'index_bootdesc'}</td>\n";
				print "</form></tr>\n";
				}

			print "</table>\n";
			}
		}
	}

&ui_print_footer("/", $text{'index'});

