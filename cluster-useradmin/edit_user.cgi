#!/usr/local/bin/perl
# edit_user.cgi
# Display a form for editing a user, or creating a new user

require './cluster-useradmin-lib.pl';
use Time::Local;
&ReadParse();
&foreign_require("useradmin", "user-lib.pl");

@hosts = &list_useradmin_hosts();
@servers = &list_servers();
if ($in{'host'} ne '') {
	($host) = grep { $_->{'id'} == $in{'host'} } @hosts;
	local ($u) = grep { $_->{'user'} eq $in{'user'} } @{$host->{'users'}};
	%uinfo = %$u;
	}
else {
	foreach $h (@hosts) {
		local ($u) = grep { $_->{'user'} eq $in{'user'} } @{$h->{'users'}};
		if ($u) {
			$host = $h;
			%uinfo = %$u;
			last;
			}
		}
	}
($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
$desc = &text('uedit_host', $serv->{'desc'} ?
		$serv->{'desc'} : $serv->{'host'});
&ui_print_header(undef, $text{'uedit_title'}, "");

# build list of used shells
foreach $h (@hosts) {
	foreach $u (@{$h->{'users'}}) {
		push(@shlist, $u->{'shell'}) if ($u->{'shell'});
		}
	}
open(SHELLS, "</etc/shells");
while(<SHELLS>) {
	s/\r|\n//g;
	s/#.*$//;
	push(@shlist, $_) if (/\S/);
	}
close(SHELLS);

print "<form action=save_user.cgi method=post>\n";
print "<input type=hidden name=olduser value=\"$in{'user'}\">\n";
print "<input type=hidden name=host value=\"$host->{'id'}\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'uedit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'user'}</b></td>\n";
print "<td><input name=user size=10 value=\"$uinfo{'user'}\"></td> </tr>\n";

print "<tr> <td><b>$text{'uid'}</b></td>\n";
printf "<td><input type=radio name=uid_def value=1 checked> %s (%s)\n",
	$text{'uedit_leave'}, $uinfo{'uid'};
printf "<input type=radio name=uid_def value=0> %s\n",
	$text{'uedit_set'};
print "<input name=uid size=10></td> </tr>\n";

if ($uconfig{'extra_real'}) {
	local @real = split(/,/, $uinfo{'real'}, 5);

	print "<tr> <td><b>$text{'real'}</b></td> <td>\n";
	printf "<input type=radio name=real_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $real[0] ? $real[0] : $text{uedit_none};
	printf "<input type=radio name=real_def value=0> %s\n",
		$text{'uedit_set'};
	print "<input name=real size=20></td> </tr>\n";

	print "<tr> <td><b>$text{'office'}</b></td> <td>\n";
	printf "<input type=radio name=office_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $real[1] ? $real[1] : $text{uedit_none};
	printf "<input type=radio name=office_def value=0> %s\n",
		$text{'uedit_set'};
	print "<input name=office size=20></td> </tr>\n";

	print "<tr> <td><b>$text{'workph'}</b></td> <td>\n";
	printf "<input type=radio name=workph_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $real[2] ? $real[2] : $text{uedit_none};
	printf "<input type=radio name=workph_def value=0> %s\n",
		$text{'uedit_set'};
	print "<input name=workph size=20></td> </tr>\n";

	print "<tr> <td><b>$text{'homeph'}</b></td> <td>\n";
	printf "<input type=radio name=homeph_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $real[3] ? $real[3] : $text{uedit_none};
	printf "<input type=radio name=homeph_def value=0> %s\n",
		$text{'uedit_set'};
	print "<input name=homeph size=20></td> </tr>\n";

	print "<tr> <td><b>$text{'extra'}</b></td> <td>\n";
	printf "<input type=radio name=extra_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $real[4] ? $real[4] : $text{uedit_none};
	printf "<input type=radio name=extra_def value=0> %s\n",
		$text{'uedit_set'};
	print "<input name=extra size=20></td> </tr>\n";
	}
else {
	if (length($uinfo{'real'}) > 20) {
		$uinfo{'real'} =~ s/,.*$//;
		}
	print "<tr> <td><b>$text{'real'}</b></td> <td>\n";
	printf "<input type=radio name=real_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'},
		$uinfo{'real'} ? $uinfo{'real'} : $text{uedit_none};
	printf "<input type=radio name=real_def value=0> %s\n",
		$text{'uedit_set'};
	print "<input name=real size=30></td> </tr>\n";
	}

print "<tr> <td><b>$text{'home'}</b></td>\n";
printf "<td><input type=radio name=home_def value=1 checked> %s (%s)\n",
	$text{'uedit_leave'}, $uinfo{'home'};
if ($uconfig{'home_base'}) {
	printf "<input type=radio name=home_def value=2> %s\n",
		$text{'uedit_auto'};
	}
printf "<input type=radio name=home_def value=0> %s\n",
	$text{'uedit_set'};
print "<input name=home size=30> ",&file_chooser_button("home", 1),
      "</td> </tr>\n";

print "<tr> <td><b>$text{'shell'}</b></td>\n";
printf "<td><input type=radio name=shell_def value=1 checked> %s (%s)\n",
	$text{'uedit_leave'}, $uinfo{'shell'};
printf "<input type=radio name=shell_def value=0> %s\n",
	$text{'uedit_set'};
print "<select name=shell>\n";
@shlist = &unique(@shlist);
foreach $s (@shlist) {
	printf "<option value='%s'>%s</option>\n", $s,
		$s eq "" ? "&lt;None&gt;" : $s;
	}
print "</select></td>\n";

print "<tr> <td valign=top><b>$text{'pass'}</b></td>\n";
printf "<td><input type=radio name=passmode value=-1 checked> %s (%s)\n",
	$text{'uedit_leave'}, $uinfo{'pass'};
printf "<input type=radio name=passmode value=0> %s\n",
	$uconfig{'empty_mode'} ? $text{'none1'} : $text{'none2'};
printf "<input type=radio name=passmode value=1> %s<br>\n", $text{'nologin'};
printf "<input type=radio name=passmode value=3> %s\n", $text{'clear'};
printf "<input %s name=pass size=15>\n",
	$uconfig{'passwd_stars'} ? "type=password" : "";
printf "<input type=radio name=passmode value=2> %s\n",
	$text{'encrypted'};
printf "<input name=encpass size=13></td> </tr>\n";

print "</table></td></tr></table><p>\n";

$pft = &foreign_call("useradmin", "passfiles_type");
if ($pft == 1 || $pft == 6) {
	# This is a BSD system.. a few extra password options are supported
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'uedit_passopts'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	print "<tr> <td><b>$text{'change2'}</b></td> <td>\n";
	printf "<input type=radio name=change_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $uinfo{'change'} ?
		    scalar(localtime($uinfo{'change'})) : $text{'uedit_none'};
	printf "<input type=radio name=change_def value=0> %s\n",
		$text{'uedit_set'};
	&date_input("", "", "", 'change');
	print " &nbsp; <input name=changeh size=3>";
	print ":<input name=changemi size=3></td> </tr>\n";

	print "<tr> <td><b>$text{'expire2'}</b></td> <td>\n";
	printf "<input type=radio name=expire_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $uinfo{'expire'} ?
		    scalar(localtime($uinfo{'expire'})) : $text{'uedit_none'};
	printf "<input type=radio name=expire_def value=0> %s\n",
		$text{'uedit_set'};
	&date_input("", "", "", 'expire');
	print " &nbsp; <input name=expireh size=3>";
	print ":<input name=expiremi size=3></td> </tr>\n";

	print "<tr> <td><b>$text{'class'}</b></td> <td>\n";
	printf "<input type=radio name=class_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $uinfo{'class'} ? $uinfo{'class'}
						      : $text{'uedit_none'};
	printf "<input type=radio name=class_def value=0> %s\n",
		$text{'uedit_set'};
	print "<input name=class size=10></td> </tr>\n";

	print "</table></td></tr></table><p>\n";
	}
elsif ($pft == 2) {
	# System has a shadow password file as well.. which means it supports
	# password expiry and so on
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'uedit_passopts'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	print "<tr> <td><b>$text{'change'}</b></td> <td>\n";
	if ($uinfo{'change'}) {
		@tm = localtime(timelocal(gmtime($uinfo{'change'} * 60*60*24)));
		printf "%s/%s/%s\n",
			$tm[3], $text{"smonth_".($tm[4]+1)}, $tm[5]+1900;
		}
	else { print "$text{'uedit_unknown'}\n"; }
	if ($uinfo{'max'}) {
		print "&nbsp; <input type=checkbox name=forcechange value=1> ",
		      "$text{'uedit_forcechange'}\n";
		}
	print "</td> </tr>\n";

	print "<td><b>$text{'expire'}</b></td> <td>\n";
	if ($uinfo{'expire'}) {
		@tm = localtime($uinfo{'expire'} * 60*60*24);
		$eday = $tm[3];
		$emon = $tm[4]+1;
		$eyear = $tm[5]+1900;
		}
	printf "<input type=radio name=expire_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $uinfo{'expire'} ? "$eday/$emon/$eyear"
						       : $text{'uedit_none'};
	printf "<input type=radio name=expire_def value=0> %s\n",
		$text{'uedit_set'};
	&date_input(undef, undef, undef, 'expire');
	print "</td> </tr>\n";

	print "<tr> <td><b>$text{'min'}</b></td>\n";
	printf "<td><input type=radio name=min_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $uinfo{'min'} ? $uinfo{'min'}
						    : $text{'uedit_none'};
	printf "<input type=radio name=min_def value=0> %s\n",
		$text{'uedit_set'};
	print "<input size=5 name=min></td> </tr>\n";

	print "<tr> <td><b>$text{'max'}</b></td>\n";
	printf "<td><input type=radio name=max_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $uinfo{'max'} ? $uinfo{'max'}
						    : $text{'uedit_none'};
	printf "<input type=radio name=max_def value=0> %s\n",
		$text{'uedit_set'};
	print "<input size=5 name=max></td></tr>\n";

	print "<tr> <td><b>$text{'warn'}</b></td>\n";
	printf "<td><input type=radio name=warn_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $uinfo{'warn'} ? $uinfo{'warn'}
						     : $text{'uedit_none'};
	printf "<input type=radio name=warn_def value=0> %s\n",
		$text{'uedit_set'};
	print "<input size=5 name=warn></td> </tr>\n";

	print "<tr> <td><b>$text{'inactive'}</b></td> <td>\n";
	printf "<input type=radio name=inactive_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $uinfo{'inactive'} ? $uinfo{'inactive'}
							 : $text{'uedit_none'};
	printf "<input type=radio name=inactive_def value=0> %s\n",
		$text{'uedit_set'};
	print "<input size=5 name=inactive></td></tr>\n";

	print "</table></td></tr></table><p>\n";
	}
elsif ($pft == 4) {
	# This is an AIX system
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'uedit_passopts'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	print "<tr> <td><b>$text{'change'}</b></td>\n";
	if ($uinfo{'change'}) {
		@tm = localtime($uinfo{'change'});
		printf "<td>%s/%s/%s %2.2d:%2.2d:%2.2d</td> </tr>\n",
			$tm[3], $text{"smonth_".($tm[4]+1)}, $tm[5]+1900,
			$tm[2], $tm[1], $tm[0];
		}
	else { print "<td>$text{'uedit_unknown'}</td> </tr>\n"; }

	print "<td><b>$text{'expire'}</b></td> <td>\n";
	if ($uinfo{'expire'}) {
		$uinfo{'expire'} =~ /^(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
		$emon = $1;
		$eday = $2;
		$ehour = $3;
		$emin = $4;
		$eyear = $5;
		if ($eyear > 38) {
			$eyear += 1900;
			}
		else {
			$eyear += 2000;
			}
		}
	$emon =~ s/0(\d)/$1/;	# strip leading 0 
	printf "<input type=radio name=expire_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'},
		$uinfo{'expire'} ? "$eday/$emon/$eyear $ehour:$emin"
				 : $text{'uedit_none'};
	printf "<input type=radio name=expire_def value=0> %s\n",
		$text{'uedit_set'};
	&date_input(undef, undef, undef, 'expire');
	print " &nbsp; <input name=expireh size=3>";
	print "<b>:</b><input name=expiremi size=3></td> </tr>\n";

	print "<tr> <td><b>$text{'min_weeks'}</b></td>\n";
	printf "<td><input type=radio name=min_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $uinfo{'min'} ? $uinfo{'min'}
						    : $text{'uedit_none'};
	printf "<input type=radio name=min_def value=0> %s\n",
		$text{'uedit_set'};
	print "<input size=5 name=min></td> </tr>\n";

	print "<td><b>$text{'max_weeks'}</b></td>\n";
	printf "<td><input type=radio name=max_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $uinfo{'max'} ? $uinfo{'max'}
						    : $text{'uedit_none'};
	printf "<input type=radio name=max_def value=0> %s\n",
		$text{'uedit_set'};
	print "<input size=5 name=max></td></tr>\n";

	print "<tr> <td valign=top><b>$text{'warn'}</b></td>\n";
	printf "<td><input type=radio name=warn_def value=1 checked> %s (%s)\n",
		$text{'uedit_leave'}, $uinfo{'warn'} ? $uinfo{'warn'}
						     : $text{'uedit_none'};
	printf "<input type=radio name=warn_def value=0> %s\n",
		$text{'uedit_set'};
	print "<input size=5 name=warn></td> </tr>\n";

	print "<td valign=top><b>$text{'flags'}</b></td> <td>\n";
	printf "<input type=radio name=flags_def value=1 checked> %s\n",
		$text{'uedit_leave'};
	printf "<input type=radio name=flags_def value=0> %s\n",
		$text{'uedit_set'};
	printf "<input type=checkbox name=flags value=admin %s> %s<br>\n",
		$text{'uedit_admin'};
	printf "<input type=checkbox name=flags value=admchg %s> %s<br>\n",
		$text{'uedit_admchg'};
	printf "<input type=checkbox name=flags value=nocheck %s> %s\n",
		$text{'uedit_nocheck'};
	print "</td> </tr>\n";

	print "</table></td></tr></table><p>\n";
	}

# Output group memberships
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'uedit_gmem'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'group'}</b></td>\n";
printf "<td><input type=radio name=gid_def value=1 checked> %s (%s)\n",
	$text{'uedit_leave'}, scalar(getgrgid($uinfo{'gid'}));
printf "<input type=radio name=gid_def value=0> %s\n",
	$text{'uedit_set'};
printf "<input name=gid size=8>\n";
print "<input type=button onClick='ifield = document.forms[0].gid; chooser = window.open(\"/useradmin/my_group_chooser.cgi?multi=0&group=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=300,height=200\"); chooser.ifield = ifield' value=\"...\"></td> </tr>\n";

foreach $g (@{$host->{'groups'}}) {
	@mems = split(/,/ , $g->{'members'});
	push(@ugroups, $g->{'group'}) if (&indexof($uinfo{'user'}, @mems) >= 0);
	}
print "<tr> <td valign=top><b>$text{'uedit_2nd'}</b></td> <td>\n";
printf "<input type=radio name=sgid_def value=0 checked> %s (%s)<br>\n",
	$text{'uedit_leave'},
	@ugroups ? join(", ", @ugroups) : $text{'uedit_none'};
printf "<input type=radio name=sgid_def value=1> %s\n",
	$text{'uedit_addto'};
printf "<input name=sgidadd size=40> %s<br>\n",
	&group_chooser_button("sgidadd", 1);
printf "<input type=radio name=sgid_def value=2> %s\n",
	$text{'uedit_delfrom'};
printf "<input name=sgiddel size=40> %s</td> </tr>\n",
	&group_chooser_button("sgiddel", 1);
print "</table></td></tr></table><p>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'onsave'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'uedit_movehome'}</b></td>\n";
print "<td><input type=radio name=movehome value=1 checked> $text{'yes'}</td>\n";
print "<td colspan=2><input type=radio name=movehome value=0> $text{'no'}</td> </tr>\n";

print "<tr> <td><b>$text{'uedit_chuid'}</b></td>\n";
print "<td><input type=radio name=chuid value=0> $text{'no'}</td>\n";
print "<td><input type=radio name=chuid value=1 checked> ",
      "$text{'home'}</td>\n";
print "<td><input type=radio name=chuid value=2> ",
      "$text{'uedit_allfiles'}</td></tr>\n";

print "<tr> <td><b>$text{'chgid'}</b></td>\n";
print "<td><input type=radio name=chgid value=0> $text{'no'}</td>\n";
print "<td><input type=radio name=chgid value=1 checked> ".
      "$text{'home'}</td>\n";
print "<td><input type=radio name=chgid value=2> ",
      "$text{'uedit_allfiles'}</td></tr>\n";

print "<tr> <td><b>$text{'uedit_servs'}</b></td>\n";
print "<td><input type=radio name=servs value=1> $text{'uedit_mall'}</td>\n";
print "<td colspan=2><input type=radio name=servs value=0 checked> $text{'uedit_mthis'}</td> </tr>\n";

print "<tr> <td><b>$text{'uedit_mothers'}</b></td>\n";
print "<td><input type=radio name=others value=1 checked> $text{'yes'}</td>\n";
print "<td colspan=2><input type=radio name=others value=0> $text{'no'}</td> </tr>\n";

print "</table></td> </tr></table><p>\n";

print "<table width=100%>\n";
print "<tr> <td><input type=submit value=\"$text{'save'}\"></td>\n";

# Find the servers this user is on
foreach $h (@hosts) {
	local ($ou) = grep { $_->{'user'} eq $in{'user'} } @{$h->{'users'}};
	if ($ou) {
		local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
		push(@icons, &get_webprefix() ?
			(&get_webprefix()."/servers/images/".$s->{'type'}.".svg") :
			("../servers/images/".$s->{'type'}.".svg"));
		push(@links, "edit_host.cgi?id=$h->{'id'}");
		push(@titles, $s->{'desc'} ? $s->{'desc'} : $s->{'host'});
		}
	}
if (@icons < @hosts) {
	# Offer to create on all servers
	print "</form><form action=\"sync.cgi\">\n";
	print "<input type=hidden name=makehome value=1>\n";
	print "<input type=hidden name=copy_files value=1>\n";
	print "<input type=hidden name=server value=-1>\n";
	print "<input type=hidden name=users_mode value=2>\n";
	print "<input type=hidden name=usel value='$uinfo{'user'}'>\n";
	print "<input type=hidden name=groups_mode value=0>\n";
	print "<input type=hidden name=user value=\"$uinfo{'user'}\">\n";
	print "<td align=middle><input type=submit ",
	      "value=\"$text{'uedit_sync'}\"></td>\n";
	}

print "</tr></table></form><p><form action=\"delete_user.cgi\">\n";
print "<input type=hidden name=user value=\"$uinfo{'user'}\">\n";
print "<input type=submit ",
      "value=\"$text{'delete'}\">\n";
print "</form><p>\n";

print &ui_hr();
print &ui_subheading($text{'uedit_hosts'});
if ($config{'table_mode'}) {
	# Show as table
	print &ui_columns_start([ $text{'index_thost'},
				  $text{'index_tdesc'},
				  $text{'index_ttype'} ]);
	foreach $h (@hosts) {
		local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
		next if (!$s);
		local ($type) = grep { $_->[0] eq $s->{'type'} }
					@servers::server_types;
		local ($link) = $config{'conf_host_links'} ?
			&ui_link("edit_host.cgi?id=$h->{'id'}",($s->{'host'} || &get_system_hostname())) :
			($s->{'host'} || &get_system_hostname());
		print &ui_columns_row([
			$link,
			$s->{'desc'},
			$type->[1],
			]);
		}
	print &ui_columns_end();
	}
else {
	# Show as icons
	&icons_table(\@links, \@titles, \@icons);
	print "<br>";
	}

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

