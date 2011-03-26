#!/usr/bin/perl
# index.cgi
# Show icons for rules, services, groups and NAT

require './itsecur-lib.pl';
&header($text{'index_title'}, "", undef, 1, 1, 0, &apply_button(), undef, undef,
	&text('index_version', $module_info{'version'}));
print "<hr>\n";

# Icons table
@can_opts = grep { $_ eq "backup" || $_ eq "restore" || $_ eq "remote" || $_ eq "import" ? &can_edit($_) : &can_use($_) } @opts;
@links = map { "list_".$_.".cgi" } @can_opts;
@titles = map { $text{$_."_title"} } @can_opts;
@icons = map { "images/".$_.".gif" } @can_opts;
@hrefs = map { ($_ eq "logs" || $_ eq "authlogs") && $config{'open_logs'} ? "target=_new" : "" } @can_opts;
&itsecur_icons_table(\@links, \@titles, \@icons, 4, \@hrefs);

if (&can_edit("apply") || &can_edit("bootup")) {
	print "<hr>\n";
	}

print "<table width=100%>\n";

if (&can_edit("apply")) {
	# Apply button
	print "<form action=apply.cgi><tr>\n";
	print "<td><input type=submit value='$text{'index_apply'}'></td>\n";
	print "<td>$text{'index_applydesc'}</td>\n";
	print "</tr></form>\n";
	}

if (&can_edit("bootup")) {
	&foreign_require("init", "init-lib.pl");
	$atboot = &init::action_status("itsecur-firewall") == 2;

	# At-boot button
	print "<tr><form action=bootup.cgi>\n";
	print "<td nowrap><input type=submit value='$text{'index_bootup'}'>\n";
	printf "<input type=radio name=boot value=1 %s> %s\n",
		$atboot ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=boot value=0 %s> %s\n",
		$atboot ? "" : "checked", $text{'no'};
	print "</td> <td>$text{'index_bootupdesc'}</td>\n";
	print "</form></tr>\n";
	}

print "</table>\n";

print "<hr>\n";
&footer("/", $text{'index'});

# itsecur_icons_table(&links, &titles, &icons, [columns], [href], [width], [height])
# Renders a 4-column table of icons
sub itsecur_icons_table
{
&load_theme_library();
if (defined(&theme_icons_table)) {
	&theme_icons_table(@_);
	return;
	}
local ($i, $need_tr);
local $cols = $_[3] ? $_[3] : 4;
local $per = int(100.0 / $cols);
print "<table width=100% cellpadding=5>\n";
for($i=0; $i<@{$_[0]}; $i++) {
	if ($i%$cols == 0) { print "<tr>\n"; }
	print "<td width=$per% align=center valign=top>\n";
	&generate_icon($_[2]->[$i], $_[1]->[$i], $_[0]->[$i],
		       ref($_[4]) ? $_[4]->[$i] : $_[4], $_[5], $_[6]);
	print "</td>\n";
        if ($i%$cols == $cols-1) { print "</tr>\n"; }
        }
while($i++%$cols) { print "<td width=$per%></td>\n"; $need_tr++; }
print "</tr>\n" if ($need_tr);
print "</table>\n";
}


