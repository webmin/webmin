#!/usr/local/bin/perl
# index.cgi
# Display logging search form

require './webminlog-lib.pl';
&foreign_require("acl", "acl-lib.pl");
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

if (!$gconfig{'log'}) {
	print &text('index_nolog', '/webmin/edit_log.cgi'),"<p>\n";
	}
elsif (!$gconfig{'logfiles'}) {
	print &text('index_nologfiles', '/webmin/edit_log.cgi'),"<p>\n";
	}

print "<form action=search.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'index_header'}</b></td> </tr>\n";
print "<tr $cb> <td>\n";

@ulist = sort { $a->{'name'} cmp $b->{'name'} } &acl::list_users();
@canulist = grep { &can_user($_->{'name'}) } @ulist;
if (@canulist == 1) {
	# Can only show one user, so skip this field
	print &ui_hidden("uall", 0),"\n";
	print &ui_hidden("user", $canulist[0]->{'name'}),"\n";
	}
else {
	# Show user selectors
	print &ui_radio("uall", 1, [ [ 1, $text{'index_uall'}."<br>" ],
				     [ 0, $text{'index_user'} ] ]),"\n";
	print "<select name=user>\n";
	foreach $u (@ulist) {
		next if (!&can_user($u->{'name'}));
		print "<option>$u->{'name'}\n";
		}
	print "</select><br>\n";
	if ($access_users{'*'}) {
		print "<input name=uall type=radio value=2> $text{'index_nuser'}\n";
		print "<select name=nuser>\n";
		foreach $u (@ulist) {
			print "<option>$u->{'name'}\n";
			}
		print "</select>\n";
		}
	print "<p>\n";
	}

print "<input name=mall type=radio value=1 checked> $text{'index_mall'}<br>\n";
print "<input name=mall type=radio value=0> $text{'index_module'}\n";
print "<select name=module>\n";
foreach $m (sort { $a->{'desc'} cmp $b->{'desc'} } &get_all_module_infos()) {
	next if (!&can_mod($m->{'dir'}));
	$mdir = &module_root_directory($m->{'dir'});
	print "<option value=$m->{'dir'}>$m->{'desc'}\n"
		if (-r "$mdir/log_parser.pl" &&
		    &check_os_support($m));
	}
print "</select><p>\n";

print "<input name=tall type=radio value=1> $text{'index_tall'}<br>\n";
print "<input name=tall type=radio value=2 checked> $text{'index_today'}<br>\n";
print "<input name=tall type=radio value=3> $text{'index_yesterday'}<br>\n";
print "<input name=tall type=radio value=0>\n";
print &text('index_time', &time_input('from'), &time_input('to')),"<p>\n";

if ($gconfig{'logfiles'}) {
	print "<input name=fall type=radio value=1 checked> $text{'index_fall'}<br>\n";
	print "<input name=fall type=radio value=0> $text{'index_file'}\n";
	print "<input name=file size=30><p>\n";
	}

if ($config{'host_search'}) {
	print "<input name=wall type=radio value=1 checked> $text{'index_wall'}<br>\n";
	print "<input name=wall type=radio value=0> $text{'index_whost'}\n";
	print "<input name=webmin size=30><p>\n";
	}

print "<div align=right>\n";
print "<input type=submit value='$text{'index_search'}'></div>\n";
print "</td> </tr></table>\n";
print "</form>\n";

&ui_print_footer("/", $text{'index'});

sub time_input
{
local $rv = "<input name=$_[0]_d size=2>/";
$rv .= "<select name=$_[0]_m>";
for($i=0; $i<12; $i++) {
	$rv .= "<option value=$i>".$text{"smonth_".($i+1)}."\n";
	}
$rv .= "</select>/<input name=$_[0]_y size=4>";
$rv .= " ".&date_chooser_button("$_[0]_d", "$_[0]_m", "$_[0]_y");
return $rv;
}

