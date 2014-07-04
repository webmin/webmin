#!/usr/local/bin/perl
# index.cgi
# Display icons for defined PPTP tunnels

require './pptp-client-lib.pl';

$vers = &get_pppd_version(\$out);
&ui_print_header(undef, $text{'index_title'}, undef, "intro", 1, 1, 0, undef, undef, undef,
	$vers ? &text('index_version', $vers) : undef);

# Create the PPTP options file if non-existent. This ensures that it can be
# used in the peer scripts, even if it is empty
if (!-r $config{'pptp_options'} && $config{'pptp_options'}) {
	&open_tempfile(OPTS, ">>$config{'pptp_options'}");
	&close_tempfile(OPTS);
	}

if (!&has_command($config{'pptp'})) {
	# The PPTP command is not installed
	print "<p>",&text('index_epptp', "<tt>$config{'pptp'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	}
elsif (!$vers) {
	# The PPP daemon is not installed
	print "<p>",&text('index_epppd', "<tt>pppd</tt>"),"<p>\n";
	}
else {
	# Show icons
	@tunnels = &list_tunnels();
	%tunnels = map { $_->{'name'}, 1 } @tunnels;
	print &ui_subheading($text{'index_header'});
	if (@tunnels) {
		@links = map { "edit.cgi?tunnel=$_->{'name'}" } @tunnels;
		@titles = map { $_->{'name'} } @tunnels;
		@icons = map { "images/tunnel.gif" } @tunnels;
		&icons_table(\@links, \@titles, \@icons);
		}
	else {
		print "<b>$text{'index_none'}</b><p>\n";
		}
	print &ui_link("edit.cgi?new=1",$text{'index_add'}),"<p>\n";

	print &ui_hr();
	print "<table width=100%>\n";
	print "<tr><form action=edit_opts.cgi>\n";
	print "<td><input type=submit ",
	      "value='$text{'index_opts'}'></td>\n";
	print "<td>$text{'index_optsdesc'}</td>\n";
	print "</form></tr>\n";

	@conns = grep { $tunnels{$_->[0]} } &list_connected();
	%conns = map { @$_ } @conns;
	@notconns = grep { !$conns{$_->{'name'}} } @tunnels;

	if (@notconns) {
		# Show connect button, if any are disconnected
		print "<tr><form action=conn.cgi><td nowrap>\n";
		print "<input type=submit value='$text{'index_conn'}'>\n";
		print "<select name=tunnel>\n";
		foreach $t (@notconns) {
			printf "<option %s>%s</option>\n",
			  $config{'tunnel'} eq $t->{'name'} ? "selected" : "",
			  $t->{'name'};
			}
		print "</select>\n";
		print $text{'index_pass'}," ",&ui_password("cpass", undef, 10);
		print "</td>\n";
		print "<td>$text{'index_conndesc'}</td> </form></tr>\n";
		}

	if (@conns) {
		# If any tunnels appear to be active, show disconnect button
		print "<tr><form action=disc.cgi><td nowrap>\n";
		print "<input type=submit value='$text{'index_disc'}'>\n";
		print "<select name=tunnel>\n";
		foreach $t (@conns) {
			printf "<option %s>%s</option>\n",
				$config{'tunnel'} eq $t->[0] ? "selected" : "",
				$t->[0];
			}
		print "</select></td>\n";
		print "<td>$text{'index_discdesc'}</td> </form></tr>\n";
		}

	# Show at-boot button
	if (&foreign_check("init") && @tunnels) {
		print "<tr>\n";
		&foreign_require("init", "init-lib.pl");
		$starting = &init::action_status($module_name);
		$config{'boot'} = undef if ($starting != 2);
		print "<form action=bootup.cgi>\n";
		print "<input type=hidden name=starting value='$starting'>\n";
		print "<td nowrap><input type=submit value='$text{'index_boot'}'>\n";
		print "<select name=tunnel>\n";
		printf "<option value='' %s>%s</option>\n",
			$config{'boot'} ? "" : "selected",
			$text{'index_noboot'};
		foreach $t (@tunnels) {
			printf "<option value='%s' %s>%s</option>\n",
			  $t->{'name'},
			  $t->{'name'} eq $config{'boot'} ?
				"selected" : "",
			  $t->{'name'};
			}
		print "</select></td>\n";
		print "<td>$text{'index_bootdesc'}</td>\n";
		print "</form></tr>\n";
		}

	print "</table>\n";
	}

&ui_print_footer("/", $text{'index'});

