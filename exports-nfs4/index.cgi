#!/usr/bin/perl
# index.cgi
# Display a list of directories and their client(s)

$| = 1;
require './exports-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
	&help_search_link("nfs exports", "man", "howto"));

if (!&has_nfs_commands()) {
	print $text{'index_eprog'},"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
}

# Display table of exports and clients
@exps = &list_exports();
if (@exps) {
	print &ui_form_start("delete_exports.cgi", "post");
	@dirs = &unique(map { $_->{'dir'} } @exps);

	# Directory list heading
	print &select_all_link("d"),"\n";
	print &select_invert_link("d"),"\n";
	print "<a href=\"edit_export.cgi?new=1\">$text{'index_add'}</a> <br>\n";
	@tds = ( "width=5" );
	print &ui_columns_start([ "",
				  $text{'index_dir'},
				  $text{'index_to'} ], 100, 0, \@tds);

	# Rows for directories and clients
	foreach $d (@dirs) {
		local @cols;
		if ($d ne $nfsv4_root) {
			push(@cols, &html_escape($d));
			}
		else {
			push(@cols, "<font color=#00ff00>".
				    &html_escape($d)." (".$text{'index_vr'}.")".
				    "</font>");
			}
		local $dirs;
		@cl = grep { $_->{'dir'} eq $d } @exps;
	    	$ccount = 0;
		foreach $c (@cl) {
			$dirs .= "&nbsp;|&nbsp; " if ($ccount++);
			$dirs .= &ui_link("edit_export.cgi?idx=$c->{'index'}",
					&describe_host($c->{'host'})),"\n";
			 if (!$c->{'active'}) {
				$dirs .= "<font color=#ff0000>(".
					 $text{'index_inactive'}.")</font>\n"
				}
			}
		push(@cols, $dirs);
		print &ui_checked_columns_row(\@cols, \@tds, "d", $d);
		}
	print &ui_columns_end();
	print &select_all_link("d"),"\n";
	print &select_invert_link("d"),"\n";
	print &ui_link("edit_export.cgi?new=1", $text{'index_add'}),"<br>\n";
	print &ui_form_end([ [ "delete", $text{'index_delete'} ],
			     [ "disable", $text{'index_disable'} ],
			     [ "enable", $text{'index_enable'} ] ]);
	}
else {
	print "<b>$text{'index_none'}</b> <p>\n";
	print &ui_link("edit_export.cgi?new=1", $text{'index_add'}),"<p>\n";
	}

print "<hr>\n";
print "<table width=100%> <tr>\n";
print "<td><form action=restart_mountd.cgi>\n";
print "<input type=submit value=\"$text{'index_apply'}\">\n";
print "</form></td>\n";
print "<td valign=top>$text{'index_applymsg'}</td>\n";
print "</tr> <tr> </table>\n";

&ui_print_footer("/", $text{'index'});

