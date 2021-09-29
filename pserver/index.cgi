#!/usr/local/bin/perl
# index.cgi
# Display a table of icons for cvs server options

require './pserver-lib.pl';
&ReadParse();

if (!$cvs_path) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	print "<p>",&text('index_ecvs', "<tt>$config{'cvs'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

$ver = &get_cvs_version(\$out);
if (!$ver) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	print "<p>",&text('index_eversion', "<tt>$config{'cvs'} -v</tt>",
			  "<pre>$out</pre>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Go direct to one icon, if it is the only one available
@avfeatures = grep { $access{$_} } @features;
if (@avfeatures == 1 && !$access{'setup'}) {
	&redirect($featureprog{$avfeatures[0]});
	exit;
	}

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, undef,
	&help_search_link("cvs", "man", "doc"), undef, undef,
	&text('index_version', $ver));

if (!-d "$config{'cvsroot'}/CVSROOT") {
	# No CVS root .. offer to setup
	print "<p>",&text('index_eroot',
		"@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";

	if ($access{'init'}) {
		print &text('index_initdesc',
			    "<tt>$config{'cvsroot'}</tt>"),"<p>\n";
		print "<form action=init.cgi>\n";
		print "<input type=submit value='$text{'index_init'}'>\n";
		print "</form>\n";
		}

	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Show configuration icons
@icons = map { "images/$_.gif" } @avfeatures;
@links = map { $featureprog{$_} } @avfeatures;
@titles = map { $text{$_."_title"} } @avfeatures;
&icons_table(\@links, \@titles, \@icons, 4);

if ($access{'setup'}) {
	# Check if run from inetd or xinetd
	print &ui_hr();
	print "<table width=100%><tr>\n";
	$inet = &check_inetd();
	if ($inet && $inet->{'args'} =~ /\s(\/\S+)\s+pserver$/) {
		$inetdir = $1;
		}
	if (!$inet) {
		print "<form action=setup.cgi>\n";
		print "<td><input type=submit value='$text{'index_setup'}'></td>\n";
		print "<td>",&text('index_setupdesc',
		   $has_xinetd ? "<tt>xinetd</tt>" : "<tt>inetd</tt>"),"<br>\n";
		print "<b>$text{'index_asuser'}</b>\n";
		print &ui_user_textbox("user", "root"),"\n";
		print "</td>\n";
		print "</form>\n";
		}
	elsif (!$inet->{'active'}) {
		print "<form action=setup.cgi>\n";
		print "<td><input type=submit value='$text{'index_act'}'></td>\n";
		if ($inetdir) {
			print "<td>",&text('index_actdesc2',
				"<tt>$inet->{'type'}</tt>",
				"<tt>$inetdir</tt>");
			}
		else {
			print "<td>",&text('index_actdesc',
				"<tt>$inet->{'type'}</tt>");
			}
		print "<br>\n";
		print "<b>$text{'index_asuser'}</b>\n";
		print &ui_user_textbox("user", $inet->{'user'}),"\n";
		print "</td>\n";
		print "</form>\n";
		}
	else {
		print "<form action=setup.cgi>\n";
		print "<td><input type=submit value='$text{'index_deact'}'></td>\n";
		if ($inetdir) {
			print "<td>",&text('index_deactdesc2',
				"<tt>$inet->{'type'}</tt>",
				"<tt>$inetdir</tt>"),"</td>\n";
			}
		else {
			print "<td>",&text('index_deactdesc',
				"<tt>$inet->{'type'}</tt>"),"</td>\n";
			}
		print "</form>\n";
		}
	print "</tr></table>\n";
	if ($inetdir && $inetdir ne $config{'cvsroot'}) {
		print "<p><center><b>$text{'index_einetroot'}</b></center>\n";
		}
	}

&ui_print_footer("/", $text{'index'});

