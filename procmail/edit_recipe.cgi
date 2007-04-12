#!/usr/local/bin/perl
# edit_receipe.cgi
# Display a form for editing or creating a procmail receipe

require './procmail-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	$block++ if ($in{'block'});
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "");
	@conf = &get_procmailrc();
	$rec = $conf[$in{'idx'}];
	$block++ if (defined($rec->{'block'}));
	}

print "<form action=save_recipe.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=before value='$in{'before'}'>\n";
print "<input type=hidden name=after value='$in{'after'}'>\n";
print "<input type=hidden name=block value='$block'>\n";

# Show action section
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header1'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($block) {
	# Start of a conditional block
	local @lines = split(/\n/, $rec->{'block'});
	local $r = @lines > 5 ? 10 : 5;
	print "<tr> <td valign=top><b>$text{'edit_block'}</b></td>\n";
	print "<td colspan=3><textarea name=bdata rows=$r cols=80>",
		$rec->{'block'},"</textarea></td> </tr>\n";
	}
else {
	# Simple action
	($t, $a) = &parse_action($rec);
	print "<tr> <td><b>$text{'edit_action'}</b></td>\n";
	print "<td colspan=3><select name=amode>\n";
	foreach $i (0, 2, 1, 3, 4, 6) {
		printf "<option value=%d %s>%s\n",
			$i, $t == $i ? "selected" : "", $text{"edit_amode_$i"};
		}
	print "</select>\n";
	printf "<input name=action size=40 value='%s'></td> </tr>\n",
		&html_escape($t == 6 ? $rec->{'action'} : $a);
	}

print "<tr> <td colspan=4><table>\n";
$i = 0;
foreach $f (@known_flags) {
	print "<tr>\n" if ($i%2 == 0);
	print "<td width=50% nowrap>\n";
	printf "<input type=checkbox name=flag value=%s %s> %s\n",
		$f, &indexof($f, @{$rec->{'flags'}}) >= 0 ? "checked" : "",
		$text{"edit_flag_$f"};
	print "</td>\n";
	print "</tr>\n" if ($i%2 == 1);
	$i++;
	}
print "</table></td> </tr>\n";

$ldef = $rec->{'lockfile'} ? 0 :
	defined($rec->{'lockfile'}) ? 2 : 1;
print "<tr> <td><b>$text{'edit_lockfile'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=lockfile_def value=1 %s> %s\n",
	$ldef == 1 ? "checked" : "", $text{'edit_none'};
printf "<input type=radio name=lockfile_def value=2 %s> %s\n",
	$ldef == 2 ? "checked" : "", $text{'default'};
printf "<input type=radio name=lockfile_def value=0 %s> %s\n",
	$ldef == 0 ? "checked" : "", $text{'edit_lock'};
printf "<input name=lockfile size=40 value='%s'></td> </tr>\n",
	&html_escape($rec->{'lockfile'});

print "</table></td></tr></table><br>\n";

# Show conditions section
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header2'}</b></td> </tr>\n";
print "<tr $cb> <td>\n";

print "$text{'edit_conddesc'}<p>\n";

$i = 0;
foreach $c (@{$rec->{'conds'}}, [ '-' ], [ '-' ] ) {
	print "<select name=cmode_$i>\n";
	printf "<option value='-' %s>&nbsp;\n",
		$c->[0] eq '-' ? "selected" : "";
	printf "<option value='' %s> %s\n",
		$c->[0] eq '' ? "selected" : "", $text{'edit_cmode_re'};
	printf "<option value='!' %s> %s\n",
		$c->[0] eq '!' ? "selected" : "", $text{'edit_cmode_nre'};
	printf "<option value='\$' %s> %s\n",
		$c->[0] eq '$' ? "selected" : "", $text{'edit_cmode_shell'};
	printf "<option value='?' %s> %s\n",
		$c->[0] eq '?' ? "selected" : "", $text{'edit_cmode_exit'};
	printf "<option value='<' %s> %s\n",
		$c->[0] eq '<' ? "selected" : "", $text{'edit_cmode_lt'};
	printf "<option value='>' %s> %s\n",
		$c->[0] eq '>' ? "selected" : "", $text{'edit_cmode_gt'};
	print "</select>\n";
	printf "<input name=cond_$i size=60 value='%s'><br>\n",
		&html_escape($c->[1]);
	$i++;
	}

print "</td></tr></table>\n";

# Show save buttons
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

