# mod_userdir.pl
# Defines editors user WWW dir directives

sub mod_userdir_directives
{
local($rv);
$rv = [ [ 'UserDir', 1, 5, 'virtual', 1.3, 6 ],
	[ 'UserDir', 0, 5, 'virtual', -1.3, 6 ] ];
return &make_directives($rv, $_[0], "mod_userdir");
}

sub edit_UserDir
{
$fmt = "<input type=radio name=UserDir_def value=1 %s> $text{'mod_userdir_default'}&nbsp\n".
       "<input type=radio name=UserDir_def value=0 %s>\n".
       "<input name=UserDir size=20 value=\"%s\"><br>\n";
if ($_[1]->{'version'} >= 1.3) {
	local($d, $v, $ud, $rv, @uinfo, $mode, @disabled, @enabled, $_, @ulist);
	foreach $d (@{$_[0]}) {
		$v = $d->{'value'};
		if ($v =~ /^(disabled|enabled)\s*(.*)$/) {
			if ($1 eq "disabled" && !$2) { $mode = 2; }
			elsif ($1 eq "disabled")
				{ $mode = 1; push(@disabled, split(/\s+/, $2)); }
			else { push(@enabled, split(/\s+/, $2)); }
			}
		else { $ud = $d->{'words'}->[0]; }
		}
	if ($mode == 1) {
		# only selected users disabled
		@ulist = @disabled;
		}
	elsif ($mode == 2) {
		# only selected users enabled
		local %dis;
		foreach (@disabled) { $dis{$_}++; }
		@ulist = grep { !$dis{$_} } @enabled;
		}
	$rv = sprintf $fmt, $ud ? "" : "checked", $ud ? "checked" : "", $ud;
	$rv .= sprintf "<input type=radio name=UserDir_mode value=0 %s>\n",
			$mode==0 ? "checked" : "";
	$rv .= "$text{'mod_userdir_all'}<br>\n";
	$rv .= sprintf "<input type=radio name=UserDir_mode value=1 %s>\n",
			$mode==1 ? "checked" : "";
	$rv .= "$text{'mod_userdir_except'} <input name=UserDir_deny size=20 value=\"".
	       ($mode==1 ? join(" ", @ulist) : "")."\"> ".
	       &user_chooser_button("UserDir_deny",1)."<br>\n";
	$rv .= sprintf "<input type=radio name=UserDir_mode value=2 %s>\n",
			$mode==2 ? "checked" : "";
	$rv .= "Only users <input name=UserDir_allow size=20 value=\"".
	       ($mode==2 ? join(" ", @ulist) : "")."\"> ".
	       &user_chooser_button("UserDir_allow",1);
	return (2, "$text{'mod_userdir_dir'}", $rv);
	}
else {
	return (1, "$text{'mod_userdir_dir'}",
	        sprintf $fmt, $_[0] ? "" : "checked", $_[0] ? "checked" : "",
	                      $_[0]->{'value'} );
	}
}
sub save_UserDir
{
if ($_[0]->{'version'} >= 1.3) {
	local(@ud);
	if ($in{'UserDir_mode'} == 1)
		{ @ud = ("disabled $in{'UserDir_deny'}"); }
	elsif ($in{'UserDir_mode'} == 2)
		{ @ud = ("disabled", "enabled $in{'UserDir_allow'}"); }
	if (!$in{'UserDir_def'}) {
		$in{'UserDir'} !~ /^\// ||
		  &allowed_doc_dir($in{'UserDir'}) ||
		    &error($text{'mod_userdir_edir'});
		push(@ud, "\"$in{'UserDir'}\"");
		}
	return ( \@ud );
	}
else {
	if ($in{'UserDir_def'}) { return ( [ ] ); }
	else { return ( [ $in{'UserDir'} ] ); }
	}
}

1;

