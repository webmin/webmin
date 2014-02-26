#!/usr/local/bin/perl
# user_form.cgi
# Display a form for creating a new user

require './cluster-useradmin-lib.pl';
use Time::Local;
&ReadParse();
&foreign_require("useradmin", "user-lib.pl");

&ui_print_header(undef, $text{'uedit_title2'}, "");
@hosts = &list_useradmin_hosts();
@servers = &list_servers();

# build list of used shells and uids
foreach $h (@hosts) {
	foreach $u (@{$h->{'users'}}) {
		push(@shlist, $u->{'shell'}) if ($u->{'shell'});
		$used{$u->{'uid'}}++;
		}
	foreach $g (@{$h->{'groups'}}) {
		push(@glist, $g) if (!$donegroup{$g->{'group'}}++);
		}
	}
open(SHELLS, "/etc/shells");
while(<SHELLS>) {
	s/\r|\n//g;
	s/#.*$//;
	push(@shlist, $_) if (/\S/);
	}
close(SHELLS);

print "<form action=create_user.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'uedit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'user'}</b></td>\n";
print "<td><input name=user size=10></td>\n";

# Find the first free UID above the base
print "<td><b>$text{'uid'}</b></td>\n";
$newuid = int($uconfig{'base_uid'});
while($used{$newuid}) {
	$newuid++;
	}
print "<td><input name=uid size=10 value='$newuid'></td> </tr>\n";

if ($uconfig{'extra_real'}) {
	print "<tr> <td><b>$text{'real'}</b></td>\n";
	print "<td><input name=real size=20></td>\n";

	print "<td><b>$text{'office'}</b></td>\n";
	print "<td><input name=office size=20 value=\"$real[1]\"></td> </tr>\n";

	print "<tr> <td><b>$text{'workph'}</b></td>\n";
	print "<td><input name=workph size=20></td>\n";

	print "<td><b>$text{'homeph'}</b></td>\n";
	print "<td><input name=homeph size=20></td> </tr>\n";

	print "<tr> <td><b>$text{'extra'}</b></td>\n";
	print "<td><input name=extra size=20></td>\n";
	}
else {
	print "<tr> <td><b>$text{'real'}</b></td>\n";
	print "<td><input name=real size=20></td>\n";
	}

print "<td><b>$text{'home'}</b></td>\n";
print "<td>\n";
if ($uconfig{'home_base'}) {
	printf "<input type=radio name=home_base value=1 checked> %s\n",
		$text{'uedit_auto'};
	printf "<input type=radio name=home_base value=0>\n";
	printf "<input name=home size=25> %s\n",
		&file_chooser_button("home", 1);
	}
else {
	print "<input name=home size=25>\n",
	      &file_chooser_button("home", 1);
	}
print "</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'shell'}</b></td>\n";
print "<td valign=top><select name=shell>\n";
@shlist = &unique(@shlist);
foreach $s (@shlist) {
	printf "<option value='%s'>%s</option>\n", $s,
		$s eq "" ? "&lt;None&gt;" : $s;
	}
print "<option value=*>$text{'uedit_other'}</option>\n";
print "</select></td>\n";

&seed_random();
foreach (1 .. 15) {
	$random_password .= $random_password_chars[
				rand(scalar(@random_password_chars))];
	}
print "<td valign=top rowspan=4><b>$text{'pass'}</b>",
      "</td> <td rowspan=4 valign=top>\n";
printf "<input type=radio name=passmode value=0> %s<br>\n",
	$uconfig{'empty_mode'} ? $text{'none1'} : $text{'none2'};
printf "<input type=radio name=passmode value=1 checked> %s<br>\n",
	$text{'nologin'};
printf "<input type=radio name=passmode value=3> %s\n",
	$text{'clear'};
printf "<input %s name=pass size=15 value='%s'><br>\n",
	$uconfig{'passwd_stars'} ? "type=password" : "",
	$uconfig{'random_password'} ? $random_password : "";
printf "<input type=radio name=passmode value=2> $text{'encrypted'}\n";
printf "<input name=encpass size=13>\n";
print "</td> </tr>\n";

print "<tr> <td valign=top>$text{'uedit_other'}</td>\n";
print "<td valign=top><input size=25 name=othersh>\n";
print &file_chooser_button("othersh", 0),"</td> </tr>\n";
print "<tr> <td colspan=2><br></td> </tr>\n";
print "</table></td></tr></table><p>\n";

$pft = &foreign_call("useradmin", "passfiles_type");
if ($pft == 1 || $pft == 6) {
	# This is a BSD system.. a few extra password options are supported
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'uedit_passopts'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	print "<tr> <td><b>$text{'change2'}</b></td>\n";
	print "<td>";
	&date_input("", "", "", 'change');
	print " &nbsp; <input name=changeh size=3>";
	print ":<input name=changemi size=3></td>\n";

	print "<td><b>$text{'expire2'}</b></td>\n";
	print "<td>";
	&date_input("", "", "", 'expire');
	print " &nbsp; <input name=expireh size=3>";
	print ":<input name=expiremi size=3></td> </tr>\n";

	print "<tr> <td><b>$text{'class'}</b></td>\n";
	print "<td><input name=class size=10></td>\n";
	print "</tr>\n";
	print "</table></td></tr></table><p>\n";
	}
elsif ($pft == 2) {
	# System has a shadow password file as well.. which means it supports
	# password expiry and so on
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'uedit_passopts'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	print "<td><b>$text{'expire'}</b></td>\n";
	print "<td>";
	&date_input($eday, $emon, $eyear, 'expire');
	print "</td> </tr>\n";

	print "<tr> <td><b>$text{'min'}</b></td>\n";
	print "<td><input size=5 name=min></td>\n";

	print "<td><b>$text{'max'}</b></td>\n";
	print "<td><input size=5 name=max></td></tr>\n";

	print "<tr> <td><b>$text{'warn'}</b></td>\n";
	print "<td><input size=5 name=warn></td>\n";

	print "<td><b>$text{'inactive'}</b></td>\n";
	print "<td><input size=5 name=inactive></td></tr>\n";

	print "</table></td></tr></table><p>\n";
	}
elsif ($pft == 4) {
	# This is an AIX system
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'uedit_passopts'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	print "<tr> <td><b>$text{'expire'}</b></td>\n";
	print "<td>";
	&date_input("", "", "", 'expire');
	print " &nbsp; <input name=expireh size=3>";
	print "<b>:</b><input name=expiremi size=3></td> </tr>\n";

	print "<tr> <td><b>$text{'min_weeks'}</b></td>\n";
	print "<td><input size=5 name=min></td>\n";

	print "<td><b>$text{'max_weeks'}</b></td>\n";
	print "<td><input size=5 name=max></td></tr>\n";

	print "<tr> <td valign=top><b>$text{'warn'}</b></td>\n";
	print "<td valign=top><input size=5 name=warn></td>\n";

	print "<td valign=top><b>$text{'flags'}</b></td> <td>\n";
	printf "<input type=checkbox name=flags value=admin> %s<br>\n",
		$text{'uedit_admin'};
	printf "<input type=checkbox name=flags value=admchg> %s<br>\n",
		$text{'uedit_admchg'};
	printf "<input type=checkbox name=flags value=nocheck> %s\n",
		$text{'uedit_nocheck'};
	print "</td> </tr>\n";

	print "</table></td></tr></table><p>\n";
	}

# Output group memberships
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'uedit_gmem'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
print "<tr> <td valign=top><b>$text{'group'}</b></td> <td valign=top>\n";
printf "<input name=gid size=8 value=\"%s\">\n",
	$uconfig{'default_group'};
print "<input type=button onClick='ifield = document.forms[0].gid; chooser = window.open(\"/useradmin/my_group_chooser.cgi?multi=0&group=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=300,height=200\"); chooser.ifield = ifield' value=\"...\"></td>\n";

print "<td valign=top><b>$text{'uedit_2nd'}</b></td>\n";
print "<td><select name=sgid multiple size=5>\n";
@glist = sort { $a->{'group'} cmp $b->{'group'} } @glist
	if ($uconfig{'sort_mode'});
foreach $g (@glist) {
	@mems = split(/,/ , $g->{'members'});
	print "<option value=\"$g->{'gid'}\">$g->{'group'} ($g->{'gid'})</option>\n";
	}
print "</select></td> </tr>\n";
print "</table></td></tr></table><p>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'uedit_oncreate'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'uedit_makehome'}</b></td>\n";
print "<td><input type=radio name=makehome value=1 checked> $text{'yes'}</td>\n";
print "<td><input type=radio name=makehome value=0> $text{'no'}</td> </tr>\n";

if ($uconfig{'user_files'} =~ /\S/) {
	print "<tr> <td><b>$text{'uedit_copy'}<b></td>\n";
	print "<td><input type=radio name=copy_files ",
	      "value=1 checked> $text{'yes'}</td>\n";
	print "<td><input type=radio name=copy_files ",
	      "value=0> $text{'no'}</td> </tr>\n";
	}

# Show make home on all servers option
print "<tr> <td><b>$text{'uedit_servs'}</b></td>\n";
print "<td><input type=radio name=servs value=1> $text{'uedit_mall'}</td>\n";
print "<td><input type=radio name=servs value=0 checked> $text{'uedit_mthis'}</td> </tr>\n";

# Show other modules option
print "<tr> <td><b>$text{'uedit_others'}</b></td>\n";
print "<td><input type=radio name=others value=1 checked> $text{'yes'}</td>\n";
print "<td><input type=radio name=others value=0> $text{'no'}</td> </tr>\n";

# Show selector for hosts to create on
&create_on_input($text{'uedit_servers'});

print "</table></td> </tr></table><p>\n";

print "<input type=submit value=\"$text{'create'}\"></form><p>\n";

&ui_print_footer("", $text{'index_return'});

# date_input(day, month, year, prefix)
sub date_input
{
print "<input name=$_[3]d size=3 value='$_[0]'>";
print "/<select name=$_[3]m>\n";
local $m;
foreach $m (1..12) {
	printf "<option value=%d %s>%s</option>\n",
		$m, $_[1] eq $m ? 'selected' : '', $text{"smonth_$m"};
	}
print "</select>";
print "/<input name=$_[3]y size=5 value='$_[2]'>";
print &date_chooser_button("$_[3]d", "$_[3]m", "$_[3]y");
}

