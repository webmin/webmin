#!/usr/local/bin/perl
# edit_group.cgi
# Edit or create a webmin group

require './acl-lib.pl';
&ReadParse();
$access{'groups'} || &error($text{'gedit_ecannot'});
if ($in{'group'}) {
	# Editing an existing group
	&ui_print_header(undef, $text{'gedit_title'}, "");
	foreach $g (&list_groups()) {
		if ($g->{'name'} eq $in{'group'}) {
			%group = %$g;
			}
		}
	}
else {
	# Creating a new group
	&ui_print_header(undef, $text{'gedit_title2'}, "");
	foreach $g (&list_groups()) {
		if ($g->{'name'} eq $in{'clone'}) {
			$group{'modules'} = $g->{'modules'};
			}
		}
	}

print "<form action=save_group.cgi method=post>\n";
print "<input type=hidden name=old value=\"$in{'group'}\">\n";
if ($in{'clone'}) {
	print "<input type=hidden name=clone value=\"$in{'clone'}\">\n";
	}
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'gedit_rights'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Show the group name
print "<tr> <td><b>$text{'gedit_group'}</b></td>\n";
print "<td><input name=name size=25 value=\"$group{'name'}\"></td>\n";

# Find and show the parent group
@glist = grep { $_->{'name'} ne $group{'name'} } &list_groups();
@mcan = $access{'gassign'} eq '*' ?
		( ( map { $_->{'name'} } @glist ), '_none' ) :
		split(/\s+/, $access{'gassign'});
map { $gcan{$_}++ } @mcan;
if (@glist && %gcan) {
	print "<td><b>$text{'edit_group'}</b></td>\n";
	print "<td><select name=group>\n";
	foreach $g (@glist) {
		local $mem = &indexof('@'.$group{'name'},
				      @{$g->{'members'}}) >= 0;
		next if (!$gcan{$g->{'name'}} && !$mem);
		printf "<option %s>%s\n",
			$mem ?  'selected' : '', $g->{'name'};
		$group = $g if ($mem);
		}
	printf "<option value='' %s>&lt;%s&gt;\n",
		$group ? '' : 'selected', $text{'edit_none'}
			if ($gcan{'_none'});
	print "</select></td>\n";
	}
print "</tr>\n";

if ($in{'group'}) {
	# Show all current members
	print "<tr> <td valign=top><b>$text{'gedit_members'}</b></td>\n";
	print "<td colspan=3><table width=100%>\n";
	$i = 0;
	foreach $m (@{$group{'members'}}) {
		print "<tr>\n" if ($i%4 == 0);
		print "<td width=25%>",($m =~ /^\@(.*)$/ ? "<i>$1</i>" : $m),
		      "</td>\n";
		print "<tr>\n" if ($i%4 == 3);
		$i++;
		}
	print "</table></td> </tr>\n";
	}

@mlist = &list_module_infos();
map { $has{$_}++ } @{$group{'modules'}};
print "<tr> <td valign=top><b>$text{'gedit_modules'}</b></td>\n";
print "<td colspan=3>\n";
print &select_all_link("mod", 0, $text{'edit_selall'}),"&nbsp;\n";
print &select_invert_link("mod", 0, $text{'edit_invert'}),"<br>\n";
@cats = &unique(map { $_->{'category'} } @mlist);
&read_file("$config_directory/webmin.catnames", \%catnames);
print "<table width=100% cellpadding=0 cellspacing=0>\n";
foreach $c (sort { $b cmp $a } @cats) {
	@cmlist = grep { $_->{'category'} eq $c } @mlist;
	print "<tr> <td colspan=2 $tb><b>",
		$catnames{$c} || $text{'category_'.$c},
		"</b></td> </tr>\n";
	$sw = 0;
	foreach $m (@cmlist) {
		local $md = $m->{'dir'};
		if (!$sw) { print "<tr>\n"; }
		print "<td width=50%>";
		printf"<input type=checkbox name=mod value=$md %s>\n",
		      $has{$md} ? "checked" : "";
		if ($access{'acl'} && $in{'group'}) {
			# Show link for editing ACL
			printf "<a href='edit_acl.cgi?mod=%s&%s=%s'>".
			       "%s</a>\n",
				&urlize($m->{'dir'}),
				"group", &urlize($in{'group'}),
				$m->{'desc'};
			}
		else {
			print "$m->{'desc'}\n";
			}
		print "</td>";
		if ($sw) { print "<tr>\n"; }
		$sw = !$sw;
		}
	}
print "</table>\n";
print &select_all_link("mod", 0, $text{'edit_selall'}),"&nbsp;\n";
print &select_invert_link("mod", 0, $text{'edit_invert'}),"\n";
print "</td> </tr>\n";
print "</table></td> </tr></table>\n";

print "<table width=100%> <tr>\n";
print "<td><input type=submit value='$text{'save'}'></td></form>\n";
if ($in{'group'}) {
	print "<form action=hide_form.cgi>\n";
	print "<input type=hidden name=group value=\"$in{'group'}\">\n";
	print "<td align=center>",
	      "<input type=submit value=\"$text{'edit_hide'}\"></td></form>\n";

	print "<form action=edit_group.cgi>\n";
	print "<input type=hidden name=clone value=\"$in{'group'}\">\n";
	print "<td align=center>",
	      "<input type=submit value=\"$text{'edit_clone'}\">",
	      "</td></form>\n";

	print "<form action=delete_group.cgi>\n";
	print "<input type=hidden name=group value=\"$in{'group'}\">\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td></form>\n";
	}
print "</tr></table>\n";

&ui_print_footer("", $text{'index_return'});

