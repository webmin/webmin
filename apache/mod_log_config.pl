# mod_log_config.pl
# Defines editors for logging

sub mod_log_config_directives
{
$rv = [ [ 'LogFormat', 1, 3, 'virtual', 1.2 ],
        [ 'TransferLog CustomLog', 1, 3, 'virtual', 1.2 ] ];
return &make_directives($rv, $_[0], "mod_log_config");
}

sub edit_LogFormat
{
if ($_[1]->{'version'} >= 1.3) {
	local($i, $v, $deffmt, @nick, @fmt, $rv);
	for($i=0; $_[0]->[$i]; $i++) {
		$vv = $_[0]->[$i]->{'words'};
		if ($vv->[1]) {
			push(@nick, $vv->[1]); push(@fmt, $vv->[0]);
			}
		else { $deffmt = $vv->[0]; }
		}
	$rv = &opt_input($deffmt, "LogFormat", "$text{'mod_log_config_common'}", 20);
	$rv .= "<br><b>$text{'mod_log_config_named'}</b><br>\n";
	$rv .= "<table border>\n".
	       "<tr $tb> <td><b>$text{'mod_log_config_nick'}</b></td> <td><b>$text{'mod_log_config_format'}</b></td> </tr>\n";
	for($i=0; $i<=@nick; $i++) {
		$rv .= "<tr $cb> <td><input name=LogFormat_nick_$i size=10 ".
		       "value=\"$nick[$i]\"></td>\n";
		$rv .= "<td><input name=LogFormat_fmt_$i size=40 ".
		       "value='$fmt[$i]'></td> </tr>\n";
		}
	$rv .= "</table>\n";
	return (2, "$text{'mod_log_config_deflog'}", $rv);
	}
else {
	return (1, "$text{'mod_log_config_deflog'}",
		&opt_input($_[0]->[0]->{'words'}->[0],
			   "LogFormat", "$text{'mod_log_config_default'}", 25));
	}
}
sub save_LogFormat
{
$in{'LogFormat'} =~ s/\"/\\\"/g;
if ($_[0]->{'version'} >= 1.3) {
	local(@rv, $i, $nick, $fmt);
	if (!$in{'LogFormat_def'}) { push(@rv, "\"$in{'LogFormat'}\""); }
	for($i=0; defined($in{"LogFormat_nick_$i"}); $i++) {
		$nick = $in{"LogFormat_nick_$i"}; $fmt =$in{"LogFormat_fmt_$i"};
		$fmt =~ s/\"/\\\"/g;
		if ($nick !~ /\S/ && $fmt !~ /\S/) { next; }
		$nick =~ /^\S+$/ || &error(&text('mod_log_config_enick', $nick));
		push(@rv, "\"$fmt\" $nick");
		}
	return ( \@rv );
	}
else {
	if ($in{'LogFormat_def'}) { return ( [ ] ); }
	elsif ($in{'LogFormat'} =~ /^\S+$/) { return ( [ $in{'LogFormat'} ] ); }
	else { return ( [ "\"$in{'LogFormat'}\"" ] ); }
	}
}

sub edit_TransferLog_CustomLog
{
local($rv, @all, $d, $i, $format, $dest);
$rv = "<table border>\n".
      "<tr $tb> <td><b>$text{'mod_log_config_format'}</b></td> <td><b>$text{'mod_log_config_write'}</b></td> ".
      "<td><b>$text{'mod_log_config_filprog'}</b></td> ";
if ($_[2]->{'version'} >= 1.305) {
	$rv .= "<td><b>$text{'mod_log_config_ifset'}</b></td> ";
	}
$rv .= "</tr>\n";
@all = (@{$_[0]}, @{$_[1]});
for($i=0; $i<=@all; $i++) {
	$d = $all[$i];
	if (!$d) { $format = ""; $dest = ""; }
	elsif ($d->{'name'} eq "CustomLog") {
		$format = $d->{'words'}->[1];
		$dest = $d->{'words'}->[0];
		}
	else {
		$format = "";
		$dest = $d->{'words'}->[0];
		}
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input type=radio name=Log_def_$i value=1 ".
              ($format ? "" : "checked")."> $text{'mod_log_config_default'}&nbsp;\n";
	$rv .= "<input type=radio name=Log_def_$i value=0 ".
	       ($format ? "checked" : "")."> <input name=Log_cust_$i size=15 ".
	       "value='$format'></td>\n";

	$rv .= "<td><input type=radio name=Log_prog_$i value=0 ".
	       ($dest =~ /^\|/ ? "" : "checked")."> $text{'mod_log_config_file'}&nbsp;\n";
	$rv .= "<input type=radio name=Log_prog_$i value=1 ".
	       ($dest =~ /^\|/ ? "checked" : "")."> $text{'mod_log_config_program'}</td>\n";

	$dest =~ s/^\|//g;
	$rv .= "<td><input name=Log_dest_$i size=30 value=\"".
	       &html_escape($dest)."\"></td>\n";
	if ($_[2]->{'version'} >= 1.305) {
		local $ev = $d->{'words'}->[2] =~ /^env=(.*)$/ ? $1 : "";
		$rv .= "<td><input name=Log_env_$i size=8 value=\"$ev\"></td>";
		}
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return (2, "$text{'mod_log_config_log'}", $rv);
}
sub save_TransferLog_CustomLog
{
local($i, $def, $cust, $prog, $dest, $fileprog, @tl, @cl);
for($i=0; defined($in{"Log_dest_$i"}); $i++) {
	$def = $in{"Log_def_$i"}; $cust = $in{"Log_cust_$i"};
	$prog = $in{"Log_prog_$i"}; $dest = $in{"Log_dest_$i"};
	$env = $in{"Log_env_$i"};
	$cust =~ s/\"/\\\"/g;
	if ($cust !~ /\S/ && $dest !~ /\S/) { next; }
	if (!$def && $cust !~ /\S/) { &error(&text('mod_log_config_eformat', $dest)); }
	if ($dest !~ /\S/) { &error($text{'mod_log_config_enofilprog'}); }
	&allowed_auth_file($dest) ||
		&error(&text('mod_log_config_efilprog', $dest));
	$prog || &directory_exists($dest) ||
		&error(&text('mod_log_config_edir', $dest));

	$fileprog = !$prog ? $dest :
		     $dest =~ /^\S+$/ ? "|$dest" : "\"|$dest\"";
	if ($def) {
		if ($env) { &error($text{'mod_log_config_eifset'}); }
		push(@tl, "$fileprog");
		}
	else {
		if ($env) { push(@cl, "$fileprog \"$cust\" env=$env"); }
		else { push(@cl, "$fileprog \"$cust\""); }
		}
	}
return ( \@tl, \@cl );
}

1;

