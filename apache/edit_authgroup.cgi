#!/usr/local/bin/perl
# edit_authgroup.cgi
# Display a form for editing a new or existing group

require './apache-lib.pl';
require './auth-lib.pl';

&ReadParse();
&allowed_auth_file($in{'file'}) ||
	&error(&text('authg_ecannot', $in{'file'}));
$desc = &text('authg_header', "<tt>$in{'file'}</tt>");
if (defined($in{'group'})) {
	# editing existing group
	&ui_print_header($desc, $text{'authg_edit'}, "");
	$g = &get_authgroup($in{'file'}, $in{'group'});
	$group = $g->{'group'};
	@members = @{$g->{'members'}};
	$new = 0;
	}
else {
	# creating a new group
	&ui_print_header($desc, $text{'authg_create'}, "");
	$new = 1;
	}

print "<form method=post action=save_authgroup.cgi>\n";
print "<input type=hidden name=file value=\"$in{'file'}\">\n";
print "<input type=hidden name=url value=\"$in{'url'}\">\n";
if (!$new) { print "<input type=hidden name=oldgroup value=$in{'group'}>\n"; }
print "<table border> <tr $tb><td colspan=2><b>",
      ($new ? $text{'authg_create'} : $text{'authg_edit'}),
      "</b></td> </tr>\n";
print "<tr $cb> <td><b>$text{'authg_group'}</b></td>\n";
print "<td><input name=group size=20 value=\"$group\"></td> </tr>\n";
print "<tr $cb> <td valign=top><b>$text{'authg_mems'}</b></td>\n";
print "<td><textarea name=members rows=5 cols=60 wrap=on>",
	join(' ', @members),"</textarea></td> </tr>\n";

print "</table><p>\n";
print "<input type=submit value=\"$text{'save'}\">\n";
print "&nbsp; <input type=submit value=\"$text{'delete'}\" name=delete>\n"
	if (!$new);
print "</form>\n";

&ui_print_footer($in{'url'}, $text{'auth_return'});

