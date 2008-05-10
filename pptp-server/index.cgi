#!/usr/local/bin/perl
# index.cgi
# Display the current PPTP configuration

require './pptp-server-lib.pl';

# Check if it is installed
if (!&has_command($config{'pptpd'}) ||
    !($vers = &get_pptpd_version(\$out))) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);
	print "<p>",&text('index_epptpd', "<tt>$config{'pptpd'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	if ($out) {
		print &text('index_ver', "$config{'pptpd'} -v"),"\n";
		print "<pre>$out</pre>\n";
		}
	}
else {
	# Show the title and version
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		&help_search_link("pptp", "man", "doc"), undef, undef,
		&text('index_version', $vers));

	if (!-r $config{'file'}) {
		# Check for the config file
		print "<p>",&text('index_econfig', "<tt>$config{'file'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
		}
	elsif (!&has_command("pppd")) {
		# Check for PPPd
		print "<p>",&text('index_epppd', "<tt>pppd</tt>"),"<p>\n";
		}
	else {
		# Show table of options
		if ($access{'conf'}) {
                  push(@links, "edit_conf.cgi");
                  push(@images, "images/conf.gif");
		  push(@titles, $text{'conf_title'});
                }
		if ($access{'options'}) {
                  push(@links, "edit_options.cgi");
                  push(@images, "images/options.gif");
                  push(@titles, $text{'options_title'});
                }
                if ($access{'secrets'}) {
                  push(@links, "list_secrets.cgi");
                  push(@images, "images/secrets.gif");
                  push(@titles, $text{'secrets_title'});
                }
                if ($access{'conns'}) {
                  push(@links, "list_conns.cgi");
                  push(@images, "images/conns.gif");
                  push(@titles, $text{'conns_title'});
                }
		&icons_table(\@links, \@titles, \@images);

		# Start or stop/apply buttons
		print &ui_hr();
		print "<table width=100%>\n";
		$pid = &get_pptpd_pid();
		if ($access{'apply'}) {
			if ($pid && kill(0, $pid)) {
				print "<form action=apply.cgi>\n";
				print "<tr> <td><input type=submit ",
				      "value='$text{'index_apply'}'></td>\n";
				print "<td>$text{'index_applydesc'}</td></tr></form>\n";
				if ($access{'stop'}) {
					print "<form action=stop.cgi>\n";
					print "<tr> <td><input type=submit ",
					      "value='$text{'index_stop'}'></td>\n";
					print "<td>$text{'index_stopdesc'}</td></tr></form>\n";
					}
				}
			else {
				print "<form action=start.cgi>\n";
				print "<tr> <td><input type=submit ",
				      "value='$text{'index_start'}'></td>\n";
				print "<td>$text{'index_startdesc'}</td></tr></form>\n";
				}
			}
		}
		print "</table>\n";
	}

&ui_print_footer("/", $text{'index'});

sub ip_table
{
local @ips = split(/,/, &find($_[0], $conf));
print "<tr> <td valign=top><b>",$text{'index_'.$_[0]},
      "</b></td> <td colspan=3>\n";
print "<textarea name=$_[0] rows=3 cols=50>",
	join("\n", @ips),"</textarea>\n";
print "</td> </tr>\n";
}

