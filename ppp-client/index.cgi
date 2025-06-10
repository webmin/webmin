#!/usr/local/bin/perl
# index.cgi
# Display a list of connections

require './ppp-client-lib.pl';
&foreign_require("proc", "proc-lib.pl");

# Check if wvdial is installed
if (!&has_command($config{'wvdial'}) ||
    ($out = &proc::pty_backquote("$config{'wvdial'} --version")) !~
     /WvDial\s+([^: \n\r]+)/i) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	print "<p>",&text('index_ewvdial', "<tt>$config{'wvdial'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	if ($out) {
		print &text('index_ver', "$config{'wvdial'} --version"),"\n";
		print "<pre>$out</pre>\n";
		}
	}
else {
	# Get the version and show title
	waitpid(-1, 1);
	$vers = $1;
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("wvdial", "man", "doc"), undef, undef,
		&text('index_version', $vers));

	if ($vers < 1.53) {
		# This version not supported
		print "<p>",&text('index_eversion', $vers, 1.53),"<p>\n";
		}
	elsif (!-r $config{'file'}) {
		# We need initialization
		print "<form action=init.cgi>\n";
		print "<center>",&text('index_init',"<tt>$config{'file'}</tt>"),
		      "<p>\n";
		print "<input type=submit value='$text{'index_ok'}'>\n";
		print "</center></form>\n";
		}
	else {
		# Show defined dialers and modems
		$conf = &get_config();
		@links = map { "edit.cgi?idx=".$_->{'index'} } @$conf;
		@icons = map { "images/modem.gif" } @$conf;
		@titles = map { &dialer_name($_->{'name'}) } @$conf;

		print &ui_subheading($text{'index_header'});
		if (@links) {
			&icons_table(\@links, \@titles, \@icons);
			}
		else {
			print "<b>$text{'index_none'}</b><p>\n";
			}
		print "<a href='edit.cgi?new=1'>$text{'index_dadd'}",
		      "</a><p>\n";

		# Show buttons for connect/disconnect and status
		local @dials = grep { $_->{'name'} =~ /^Dialer\s+/i }
				    @$conf;
		print &ui_hr();
		print "<table width=100%>\n";
		($ip, $pid, $sect) = &get_connect_details();
		if ($ip && kill(0, $pid)) {
			# Connected .. offer to disconnect
			print "<form action=disconnect.cgi><tr>\n";
			print "<input type=hidden name=mode value=0>\n";
			print "<td><input type=submit ",
			      "value='$text{'index_disc'}'></td>\n";
			print "<td>",&text($ip eq "*" ? 'index_discdesc3' :
					   'index_discdesc1', "<tt>$ip</tt>",
					   &dialer_name($sect)),"</td>\n";
			print "</tr></form>\n";
			}
		elsif ($pid = &get_wvdial_pid()) {
			# Running, but started elsewhere
			print "<form action=disconnect.cgi><tr>\n";
			print "<input type=hidden name=mode value=1>\n";
			print "<td><input type=submit ",
			      "value='$text{'index_disc'}'></td>\n";
			print "<td>",&text('index_discdesc2', $pid),"</td>\n";
			print "</tr></form>\n";
			}
		else {
			# Not connected .. offer to dial up
			if (@dials) {
				print "<form action=connect.cgi><tr>\n";
				print "<td nowrap><input type=submit ",
				      "value='$text{'index_connect'}'>\n";
				print "<select name=section>\n";
				foreach $c (@dials) {
					printf "<option value='%s' %s>%s</option>\n",
					  $c->{'name'},
					  $c->{'name'} eq $config{'dialer'} ?
						"selected" : "",
					  &dialer_name($c->{'name'});
					}
				print "</select></td>\n";
				print "<td>$text{'index_connectdesc'}</td>\n";
				print "</tr></form>\n";
				}
			}

		# Show at-boot button
		if (&foreign_check("init") && @dials) {
			print "<tr>\n";
			&foreign_require("init", "init-lib.pl");
			$starting = &init::action_status($module_name);
			$config{'boot'} = undef if ($starting != 2);
			print "<form action=bootup.cgi>\n";
			print "<input type=hidden name=starting value='$starting'>\n";
			print "<td nowrap><input type=submit value='$text{'index_boot'}'>\n";
			print "<select name=section>\n";
			printf "<option value='' %s>%s</option>\n",
				$config{'boot'} ? "" : "selected",
				$text{'index_noboot'};
			foreach $c (@dials) {
				printf "<option value='%s' %s>%s</option>\n",
				  $c->{'name'},
				  $c->{'name'} eq $config{'boot'} ?
					"selected" : "",
				  &dialer_name($c->{'name'});
				}
			print "</select></td>\n";
			print "<td>$text{'index_bootdesc'}</td>\n";
			print "</form></tr>\n";
			}

		# Show re-config button
		print "<form action=init.cgi><tr>\n";
		print "<td><input type=submit ",
		      "value='$text{'index_refresh'}'></td>\n";
		print "<td>$text{'index_refreshdesc'}</td>\n";
		print "</tr></form>\n";

		print "</table>\n";
		}
	}

&ui_print_footer("/", $text{'index'});


