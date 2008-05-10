#!/usr/local/bin/perl
# index.cgi
# Display jabber configuration option categories

require './jabber-lib.pl';

# Check if config file exists
if (!-r $config{'jabber_config'}) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, undef,
		&help_search_link("jabber", "man", "doc", "google"));
	print &text('index_econfig', "<tt>$config{'jabber_config'}</tt>",
		    "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
	}

# Check if base directory exists
if (!-d $config{'jabber_dir'}) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, undef,
		&help_search_link("jabber", "man", "doc", "google"));
	print &text('index_edir', "<tt>$config{'jabber_dir'}</tt>",
		    "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
	}

# Check the version of jabberd
$jabberd = $config{'jabber_daemon'} ? $config{'jabber_daemon'}
				    : "$config{'jabber_dir'}/bin/jabberd";
if (!-x $jabberd) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, undef,
		&help_search_link("jabber", "man", "doc", "google"));
	print &text('index_ejabberd', "<tt>$jabberd</tt>",
		    "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
	}
$ver = &get_jabberd_version(\$out);
if (!$ver) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, undef,
		&help_search_link("jabber", "man", "doc", "google"));
	print &text('index_eversion', "<pre>$out</pre>", "1.4",
		    "<tt>$jabberd -v</tt>"),"<p>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
	}
elsif ($ver >= 2) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, undef,
		&help_search_link("jabber", "man", "doc", "google"));
	print &text('index_eversion2', "<pre>$out</pre>", "2.0",
		    "<tt>$jabberd -v</tt>"),"<p>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
	}

&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, undef,
	&help_search_link("jabber", "man", "doc", "google"),
	undef, undef, &text('index_version', $ver));

# Check if the needed Perl module are installed
push(@needs, "XML::Parser") if (!$got_xml_parser);
push(@needs, "XML::Generator") if (!$got_xml_generator);
if (@needs) {
	$needs = &urlize(join(" ", @needs));
	print &text(@needs == 2 ? 'index_emodules' : 'index_emodule', @needs,
	    "/cpan/download.cgi?source=3&cpan=$needs&mode=2&return=/$module_name/&returndesc=".&urlize($text{'index_return'})),"<p>\n";
	print "$text{'index_expat'}<p>\n";
	print &ui_hr();
	&ui_print_footer("/", $text{"index"});
	exit;
	}

# Show config category icons
$conf = &get_jabber_config();
if (!ref($conf)) {
	print &text('index_eparse', "<tt>XML::Parser</tt>", $conf),"<p>\n";
	print &ui_hr();
	&ui_print_footer("/", $text{"index"});
	exit;
	}
@cats = ( "general", "messages", "modules", "karma", "ips", "filter", "admin", "file" );
@links = map { "edit_${_}.cgi" } @cats;
@titles = map { $text{"${_}_title"} } @cats;
@icons = map { "images/${_}.gif" } @cats;
&icons_table(\@links, \@titles, \@icons);

# Show warning about config file
open(CONFIG, $config{'jabber_config'});
while(<CONFIG>) {
	if (/\s+<!--/) {
		$has_comment++;
		last;
		}
	}
close(CONFIG);
print "<b>",&text('index_comments',
	  "<tt>$config{'jabber_config'}</tt>"),"</b><p>\n" if ($has_comment);

# Check if jabber is running and show the correct buttons
print &ui_hr();
print "<table width=100%>\n";
if (&check_pid_file(&jabber_pid_file())) {
	# Running .. offer to restart and stop
	print "<form action=restart.cgi><tr>\n";
	print "<td><input type=submit value=\"$text{'index_restart'}\"></td>\n";
	print "<td>$text{'index_restartmsg'}</td>\n";
	print "</tr></form>\n";

	print "<form action=stop.cgi><tr>\n";
	print "<td><input type=submit value=\"$text{'index_stop'}\"></td>\n";
	print "<td>$text{'index_stopmsg'}</td>\n";
	print "</tr></form>\n";
	}
else {
	# Not running .. offer to start
	print "<form action=start.cgi><tr>\n";
	print "<td><input type=submit value=\"$text{'index_start'}\"></td>\n";
	print "<td>$text{'index_startmsg'}</td>\n";
	print "</tr></form>\n";
	}
print "</table>\n";
close(PID);

&ui_print_footer("/", $text{'index'});

