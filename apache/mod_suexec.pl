# mod_suexec.pl
# Editors for per-virtuser suexec directives

sub mod_suexec_directives
{
local $rv;
$rv = [ [ 'SuexecUserGroup', 0, 8, 'virtual', 2.0 ] ];
return &make_directives($rv, $_[0], "mod_suexec");
}

sub edit_SuexecUserGroup
{
local $rv;
$rv .= sprintf "<input type=radio name=SuexecUserGroup_def value=1 %s> %s\n",
		$_[0] ? "" : "checked", $text{'suexec_none'};
$rv .= sprintf "<input type=radio name=SuexecUserGroup_def value=0 %s>\n",
		$_[0] ? "checked" : "";
$rv .= sprintf "%s <input name=SuexecUserGroup_u size=8 value='%s'> %s\n",
		$text{'suexec_user'}, $_[0]->{'words'}->[0],
		&user_chooser_button("SuexecUserGroup_u");
$rv .= sprintf "%s <input name=SuexecUserGroup_g size=8 value='%s'> %s\n",
		$text{'suexec_group'}, $_[0]->{'words'}->[1],
		&group_chooser_button("SuexecUserGroup_g");
return (2, $text{'suexec_su'}, $rv);
}
sub save_SuexecUserGroup
{
if ($in{'SuexecUserGroup_def'}) {
	return ( [ ] );
	}
else {
	$in{'SuexecUserGroup_u'} =~ /^#-?\d+$/ ||
		defined(getpwnam($in{'SuexecUserGroup_u'})) ||
			&error($text{'suexec_euser'});
	$in{'SuexecUserGroup_g'} =~ /^#-?\d+$/ ||
		defined(getgrnam($in{'SuexecUserGroup_g'})) ||
			&error($text{'suexec_egroup'});
	return ( [ $in{'SuexecUserGroup_u'}." ".$in{'SuexecUserGroup_g'} ] );
	}
}

