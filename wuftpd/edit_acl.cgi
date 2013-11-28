#!/usr/local/bin/perl
# edit_acl.cgi
# Display access control options

require './wuftpd-lib.pl';
&ui_print_header(undef, $text{'acl_title'}, "", "acl");

$conf = &get_ftpaccess();
@class = &find_value("class", $conf);

print "<form action=save_acl.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'acl_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Display addresses to deny from
@deny = ( &find_value("deny", $conf), [ ] );
print "<tr> <td valign=top><b>$text{'acl_deny'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'acl_daddrs'}</b></td>\n",
      "<td><b>$text{'acl_dmsg'}</b></td> </tr>\n";
$i = 0;
foreach $d (@deny) {
	print "<tr $cb>\n";
	print "<td><input name=daddrs_$i size=20 value='$d->[0]'></td>\n";
	print "<td><input name=dmsg_$i size=35 value='$d->[1]'></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";
print "<tr> <td colspan=4><hr></td> </tr>\n";

# Display concurrent login limits
@limit = ( &find_value("limit", $conf), [ ] );
print "<tr> <td valign=top><b>$text{'acl_limit'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'acl_class'}</b></td>\n",
      "<td><b>$text{'acl_n'}</b></td>\n",
      "<td><b>$text{'acl_times'}</b></td>\n",
      "<td><b>$text{'acl_lmsg'}</b></td> </tr>\n";
$i = 0;
foreach $l (@limit) {
	print "<tr $cb>\n";
	print "<td><select name=lclass_$i>\n";
	printf "<option value='' %s>&nbsp;</option>\n", $l->[0] ? '' : 'checked';
	foreach $c (@class) {
		printf "<option %s>%s</option>\n",
			$l->[0] eq $c->[0] ? 'selected' : '', $c->[0];
		}
	print "</select></td>\n";

	printf "<td><input type=radio name=ln_def_$i value=1 %s> %s\n",
		$l->[1] =~ /^\d+$/ ? '' : 'checked', $text{'acl_unlimited'};
	printf "<input type=radio name=ln_def_$i value=0 %s>\n",
		$l->[1] =~ /^\d+$/ ? 'checked' : '';
	printf "<input name=ln_$i size=8 value='%s'></td>\n",
		$l->[1] =~ /^\d+$/ ? $l->[1] : '';

	printf "<td><input type=radio name=ltimes_def_$i value=1 %s> %s\n",
		lc($l->[2]) eq 'any' ? 'checked' : '', $text{'acl_any'};
	printf "<input type=radio name=ltimes_def_$i value=0 %s>\n",
		lc($l->[2]) eq 'any' ? '' : 'checked';
	printf "<input name=ltimes_$i size=10 value='%s'></td>\n",
		lc($l->[2]) eq 'any' ? '' : $l->[2];

	print "<td><input name=lmsg_$i size=20 value='$l->[3]'></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";
print "<tr> <td colspan=4><hr></td> </tr>\n";

# Display file and byte limits
@fblimit = sort { $a->{'line'} <=> $b->{'line'} }
		( &find("file-limit", $conf), &find("data-limit", $conf) );
push(@fblimit, { });
print "<tr> <td valign=top><b>$text{'acl_file'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'acl_fblimit'}</b></td>\n",
      "<td><b>$text{'acl_inout'}</b></td>\n",
      "<td><b>$text{'acl_raw'}</b></td>\n",
      "<td><b>$text{'acl_count'}</b></td>\n",
      "<td><b>$text{'acl_class'}</b></td> </tr>\n";
$i = 0;
foreach $l (@fblimit) {
	$f = $l->{'values'};
	splice(@$f, 0, 0, '0') if ($f->[0] ne 'raw');
	print "<tr $cb>\n";
	print "<td><select name=fblimit_$i>\n";
	printf "<option value='' %s>&nbsp;</option>\n",
		$l->{'name'} ? '' : 'selected';
	printf "<option value=file-limit %s>%s</option>\n",
		$l->{'name'} eq 'file-limit' ? 'selected' : '',
		$text{'acl_flimit'};
	printf "<option value=byte-limit %s>%s</option>\n",
		$l->{'name'} eq 'byte-limit' ? 'selected' : '',
		$text{'acl_blimit'};
	print "</select></td>\n";

	print "<td><select name=fbinout_$i>\n";
	printf "<option value=total %s>%s</option>\n",
		$f->[1] eq 'total' ? 'selected' : '', $text{'acl_total'};
	printf "<option value=in %s>%s</option>\n",
		$f->[1] eq 'in' ? 'selected' : '', $text{'acl_in'};
	printf "<option value=out %s>%s</option>\n",
		$f->[1] eq 'out' ? 'selected' : '', $text{'acl_out'};
	print "</select></td>\n";

	printf "<td><input type=radio name=fbraw_$i value=0 %s> %s\n",
		$f->[0] eq 'raw' ? '' : 'checked', $text{'yes'};
	printf "<input type=radio name=fbraw_$i value=1 %s> %s</td>\n",
		$f->[0] eq 'raw' ? 'checked' : '', $text{'no'};

	print "<td><input name=fbcount_$i size=10 value='$f->[2]'></td>\n";

	print "<td><select name=fbclass_$i>\n";
	printf "<option value='' %s>%s</option>\n",
		$f->[3] ? '' : 'selected', $text{'acl_all'};
	foreach $c (@class) {
		printf "<option %s>%s</option>\n",
			$f->[3] eq $c->[0] ? 'selected' : '', $c->[0];
		}
	print "</select></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";
print "<tr> <td colspan=4><hr></td> </tr>\n";

# File access controls
@noret = ( &find_value("noretrieve", $conf), [ ] );
print "<tr> <td valign=top><b>$text{'acl_noret'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'acl_nfiles'}</b></td>\n",
      "<td><b>$text{'acl_nrel'}</b></td>\n",
      "<td><b>$text{'acl_nclass'}</b></td> </tr>\n";
$i = 0;
foreach $n (@noret) {
	local (@f, %c);
	foreach $nn (@$n) {
		if ($nn =~ /^class=(\S+)/) { $c{$1}++; }
		elsif ($nn !~ /^(absolute|relative)$/) { push(@f, $nn); }
		}
	print "<tr $cb>\n";
	printf "<td><input name=nfiles_$i size=30 value='%s'></td>\n",
		join(" ", @f);
	printf "<td><input type=radio name=nrel_$i value=1 %s> %s\n",
		$n->[0] eq 'relative' ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=nrel_$i value=0 %s> %s</td>\n",
		$n->[0] eq 'relative' ? '' : 'checked', $text{'no'};
	print "<td>\n";
	foreach $c (@class) {
		printf "<input type=checkbox name=nclass_$i value=%s %s> %s\n",
			$c->[0], !%c || $c{$c->[0]} ? 'checked' : '', $c->[0];
		}
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";

@allowret = ( &find_value("allow-retrieve", $conf), [ ] );
print "<tr> <td valign=top><b>$text{'acl_allowret'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'acl_afiles'}</b></td>\n",
      "<td><b>$text{'acl_arel'}</b></td>\n",
      "<td><b>$text{'acl_aclass'}</b></td> </tr>\n";
$i = 0;
foreach $n (@allowret) {
	local (@f, %c);
	foreach $nn (@$n) {
		if ($nn =~ /^class=(\S+)/) { $c{$1}++; }
		elsif ($nn !~ /^(absolute|relative)$/) { push(@f, $nn); }
		}
	print "<tr $cb>\n";
	printf "<td><input name=afiles_$i size=30 value='%s'></td>\n",
		join(" ", @f);
	printf "<td><input type=radio name=arel_$i value=1 %s> %s\n",
		$n->[0] eq 'relative' ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=arel_$i value=0 %s> %s</td>\n",
		$n->[0] eq 'relative' ? '' : 'checked', $text{'no'};
	print "<td>\n";
	foreach $c (@class) {
		printf "<input type=checkbox name=aclass_$i value=%s %s> %s\n",
			$c->[0], !%c || $c{$c->[0]} ? 'checked' : '', $c->[0];
		}
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";
print "<tr> <td colspan=4><hr></td> </tr>\n";

# Display time-limit options
foreach $l (&find_value("limit-time", $conf)) {
	if ($l->[0] eq '*') {
		$limit{'anonymous'} = $limit{'guest'} = $l->[1];
		}
	else {
		$limit{$l->[0]} = $l->[1];
		}
	}
print "<tr> <td><b>$text{'acl_alimit'}</b></td>\n";
printf "<td><input type=radio name=alimit_def value=1 %s> %s\n",
	$limit{'anonymous'} ? '' : 'checked', $text{'acl_unlimited'};
printf "<input type=radio name=alimit_def value=0 %s>\n",
	$limit{'anonymous'} ? 'checked' : '';
printf "<input name=alimit size=6 value='%s'> %s</td>\n",
	$limit{'anonymous'}, $text{'acl_mins'};
print "<td><b>$text{'acl_glimit'}</b></td>\n";
printf "<td><input type=radio name=glimit_def value=1 %s> %s\n",
	$limit{'guest'} ? '' : 'checked', $text{'acl_unlimited'};
printf "<input type=radio name=glimit_def value=0 %s>\n",
	$limit{'guest'} ? 'checked' : '';
printf "<input name=glimit size=6 value='%s'> %s</td> </tr>\n",
	$limit{'guest'}, $text{'acl_mins'};

# Other security options
$lf = &find_value('loginfails', $conf);
print "<tr> <td><b>$text{'acl_fails'}</b></td>\n";
printf "<td><input type=radio name=fails_def value=1 %s> %s\n",
	$lf ? '' : 'checked', $text{'default'};
printf "<input type=radio name=fails_def value=0 %s>\n",
	$lf ? 'checked' : '';
print "<input name=fails size=6 value='$lf->[0]'></td>\n";

$pr = &find_value('private', $conf); 
print "<td><b>$text{'acl_private'}</b></td>\n";
printf "<td><input type=radio name=private value=yes %s> %s\n",
	$pr->[0] eq 'yes' ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=private value=no %s> %s</td> </tr>\n",
	$pr->[0] eq 'yes' ? '' : 'checked',  $text{'no'};

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

