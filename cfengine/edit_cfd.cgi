#!/usr/local/bin/perl
# edit_cfd.cgi
# Display options for the cfengine daemon on this host

require './cfengine-lib.pl';
&ui_print_header(undef, $text{'cfd_title'}, "", "cfd");

if (!&has_command($config{'cfd'})) {
	print &text('cfd_ecmd', "<tt>$config{'cfd'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Display table of daemon options
$conf = &get_cfd_config();
@secs = grep { $_->{'type'} eq 'section' } @$conf;
&show_classes_table(\@secs, 1);

# Allow starting or stopping of cfd
($pid) = &find_byname("cfd");
print &ui_hr();
print "<table width=100%><tr>\n";
if ($pid) {
	print "<form action=stop.cgi>\n";
	print "<td><input type=submit value='$text{'cfd_stop'}'></td>\n";
	print "<td>$text{'cfd_stopdesc'}</td>\n";
	print "</form>\n";
	}
else {
	print "<form action=start.cgi>\n";
	print "<td><input type=submit value='$text{'cfd_start'}'></td>\n";
	print "<td>$text{'cfd_startdesc'}</td>\n";
	print "</form>\n";
	}
print "</tr></table>\n";

&ui_print_footer("", $text{'index_return'});

