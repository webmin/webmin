#!/usr/local/bin/perl
# edit_white.cgi
# Display white and black lists of to and from addresses

require './spam-lib.pl';
&can_use_check("white");
&ui_print_header(undef, $text{'white_title'}, "");
$conf = &get_config();

print "$text{'white_desc'}<p>\n";
&start_form("save_white.cgi", $text{'white_header'});

print "<tr> <td width=50%><b>$text{'white_from'}</b></td> ",
      "<td width=50%><b>$text{'white_unfrom'}</b></td> </tr>\n";
print "<tr> <td width=50%>\n";
@from = &find("whitelist_from", $conf);
&edit_textbox("whitelist_from", [ map { @{$_->{'words'}} } @from ], 40, 5);
print "</td> <td width=50%>\n";
@un = &find("unwhitelist_from", $conf);
&edit_textbox("unwhitelist_from", [ map { @{$_->{'words'}} } @un ], 40, 5);
print "</td> </tr>\n";

if ($config{'show_global'}) {
	print "<tr> <td width=50%><b>$text{'white_gfrom'}</b></td> ",
	      "<td width=50%><b>$text{'white_gunfrom'}</b></td> </tr>\n";
	$gconf = &get_config($config{'global_cf'}, 1);
	print "<tr> <td width=50%>\n";
	@gfrom = &find("whitelist_from", $gconf);
	&edit_textbox("gwhitelist_from", [ map { @{$_->{'words'}} } @gfrom ], 40, 5);
	print "</td> <td width=50%>\n";
	@gun = &find("unwhitelist_from", $gconf);
	&edit_textbox("gunwhitelist_from", [ map { @{$_->{'words'}} } @gun ], 40, 5);
	print "</td> </tr>\n";
	print "<script>\n";
	print "document.forms[0].gwhitelist_from.disabled = true;\n";
	print "document.forms[0].gunwhitelist_from.disabled = true;\n";
	print "</script>\n";
	}
else {
	print "<tr> <td colspan=2><b>$text{'white_rcvd'}</b></td> </tr>\n";
	print "<tr> <td colspan=2>\n";
	@rcvd = &find("whitelist_from_rcvd", $conf);
	&edit_table("whitelist_from_rcvd",
		    [ $text{'white_addr'}, $text{'white_rcvdhost'} ],
		    [ map { $_->{'words'} } @rcvd ], [ 40, 30 ], undef, 3);
	print "</td> </tr>\n";
	}

print "<tr> <td colspan=2><hr></td> </tr>\n";

print "<tr> <td><b>$text{'white_black'}</b></td> ",
      "<td><b>$text{'white_unblack'}</b></td> </tr>\n";
print "<tr> <td>\n";
@from = &find("blacklist_from", $conf);
&edit_textbox("blacklist_from", [ map { @{$_->{'words'}} } @from ], 40, 5);
print "</td> <td>\n";
@un = &find("unblacklist_from", $conf);
&edit_textbox("unblacklist_from", [ map { @{$_->{'words'}} } @un ], 40, 5);
print "</td> </tr>\n";

if ($config{'show_global'}) {
	print "<tr> <td><b>$text{'white_gblack'}</b></td> ",
	      "<td><b>$text{'white_gunblack'}</b></td> </tr>\n";
	print "<tr> <td>\n";
	@gfrom = &find("blacklist_from", $gconf);
	&edit_textbox("gblacklist_from", [ map { @{$_->{'words'}} } @gfrom ], 40, 5);
	print "</td> <td>\n";
	@gun = &find("gunblacklist_from", $gconf);
	&edit_textbox("gunblacklist_from", [ map { @{$_->{'words'}} } @gun ], 40, 5);
	print "</td> </tr>\n";
	print "<script>\n";
	print "document.forms[0].gblacklist_from.disabled = true;\n";
	print "document.forms[0].gunblacklist_from.disabled = true;\n";
	print "</script>\n";
	}
else {
	print "<tr> <td colspan=2><hr></td> </tr>\n";

	push(@to, map { [ $_, 0 ] } map { @{$_->{'words'}} } &find("whitelist_to", $conf));
	push(@to, map { [ $_, 1 ] } map { @{$_->{'words'}} } &find("more_spam_to", $conf));
	push(@to, map { [ $_, 2 ] } map { @{$_->{'words'}} } &find("all_spam_to", $conf));
	print "<tr> <td colspan=2><b>$text{'white_to'}</b></td> </tr>\n";
	print "<tr> <td colspan=2>\n";
	&edit_table("whitelist_to", [ $text{'white_addr'}, $text{'white_level'} ],
		    \@to, [ 40, 0 ], \&whitelist_to_conv, 3);
	print "</td> </tr>\n";
	}

&end_form(undef, $text{'save'});

# Show whitelist import form
print "<hr>\n";
print "$text{'white_importdesc'}<p>\n";
print "<form action=import.cgi method=post enctype=multipart/form-data>\n";
print "<table>\n";
print "<tr> <td><b>$text{'white_import'}</b></td>\n";
print "<td><input type=file name=import></td> </tr>\n";
print "<tr> <td><b>$text{'white_sort'}</b></td>\n";
print "<td><input type=radio name=sort value=1> $text{'yes'}\n";
print "<input type=radio name=sort value=0 checked> $text{'no'}</td> </tr>\n";
print "</table>\n";
print "<input type=submit value='$text{'white_importok'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

# whitelist_to_conv(col, name, size, value)
sub whitelist_to_conv
{
if ($_[0] == 0) {
	return &default_convfunc(@_);
	}
else {
	local $rv = "<select name=$_[1]>\n";
	foreach $l (0 .. 2) {
		$rv .= sprintf "<option value=%d %s>%s\n",
			$l, $l == $_[3] ? "selected" : "", $text{"white_level$l"};
		}
	$rv .= "</select>\n";
	return $rv;
	}
}

