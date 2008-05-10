#!/usr/local/bin/perl
# index.cgi
# Display a list of directories and their client(s)

$| = 1;
require './exports-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);

if (!&has_nfs_commands()) {
	print "<p>",$text{'index_eprog'},"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

@exps = &list_exports();
if (@exps) {
	@dirs = &unique(map { $_->{'dir'} } @exps);
	if ($access{'icons'}) {
		# Display icons for exports
		foreach $d (@dirs) {
			@cl = grep { $_->{'dir'} eq $d } @exps;
			foreach $c (@cl) {
				push(@icons, "images/export.gif");
				local $desc = &describe_host($c->{'host'});
				if ($c->{'active'}) {
					push(@titles, $d.'<br>'.$desc);
					}
				else {
					push(@titles, '<font color=#ff0000>'.
					     $d.'<br>'.$desc.'</font>');
					}
				push(@links,
				     "edit_export.cgi?idx=$c->{'index'}");
				}
			}
		&icons_table(\@links, \@titles, \@icons);
		}
	else {
		# Display table of exports and clients
		print "<table border width=100%>\n";
		print "<tr $tb> <td><b>$text{'index_dir'}</b></td> ",
		      "<td><b>$text{'index_to'}</b></td> </tr>\n";
		foreach $d (@dirs) {
			print "<tr $cb> <td valign=top>$d</td>\n";
			print "<td>\n";
			@cl = grep { $_->{'dir'} eq $d } @exps;
			$ccount = 0;
			foreach $c (@cl) {
				print "&nbsp;|&nbsp; " if ($ccount++);
				print "<a href=\"edit_export.cgi?idx=$c->{'index'}\">",&describe_host($c->{'host'}),"</a>\n";
				print "<font color=#ff0000>($text{'index_inactive'})","</font>\n" if (!$c->{'active'});
				}
			print "</td> </tr>\n";
			}
		print "</table>\n";
		}
	}
else {
	print "<b>$text{'index_none'}</b> <p>\n";
	}
print "<a href=\"edit_export.cgi?new=1\">$text{'index_add'}</a> <p>\n";

print &ui_hr();
print "<table width=100%> <tr>\n";
print "<td><form action=restart_mountd.cgi>\n";
print "<input type=submit value=\"$text{'index_apply'}\">\n";
print "</form></td>\n";
print "<td valign=top>$text{'index_applymsg'}</td>\n";
print "</tr> <tr> </table>\n";

&ui_print_footer("/", $text{'index'});

