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
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	}
elsif (!$vers) {
	# The PPP daemon is not installed
	print "<p>",&text('index_eppp', "<tt>pppd</tt>"),"<p>\n";
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
	print &ui_buttons_start();

	# Show edit options button
	print &ui_buttons_row("edit_opts.cgi",
		$text{'index_opts'}, $text{'index_optsdesc'});

	@conns = grep { $tunnels{$_->[0]} } &list_connected();
	%conns = map { @$_ } @conns;
	@notconns = grep { !$conns{$_->{'name'}} } @tunnels;

	if (@notconns) {
		# Show connect button, if any are disconnected
		print &ui_buttons_row("conn.cgi",
			$text{'index_conn'},
			$text{'index_conndesc'},
			undef,
			&ui_select("tunnel", $config{'tunnel'},
				[ map { $_->{'name'} } @notconns ])." ".
			    $text{'index_pass'}." ".
			    &ui_password("cpass", undef, 10));
		}

	if (@conns) {
		# If any tunnels appear to be active, show disconnect button
		print &ui_buttons_row("disc.cgi",
			$text{'index_disc'},
			$text{'index_discdesc'},
			undef,
			&ui_select("tunnel", $config{'tunnel'},
				[ map { $_->[0] } @conns ]));
		}

	# Show at-boot button
	if (&foreign_check("init") && @tunnels) {
		&foreign_require("init");
		$starting = &init::action_status($module_name);
		$config{'boot'} = undef if ($starting != 2);
		print &ui_buttons_row("bootup.cgi",
			$text{'index_boot'},
			$text{'index_bootdesc'},
			&ui_hidden("starting", $starting),
			&ui_select("tunnel", $config{'boot'},
				[ [ "", $text{'index_noboot'} ],
				  map { [ $_->{'name'} ] } @tunnels ]));
		}

	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});

