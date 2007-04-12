
do 'xinetd-lib.pl';

sub show_add_dir
{
local $rv;
$rv .= sprintf "<input type=radio name=add_dir_def value=1 %s> %s\n",
	$_[0] ? "" : "checked", $text{'config_dirdef'};
$rv .= sprintf "<input type=radio name=add_dir_def value=0 %s> %s\n",
	$_[0] ? "checked" : "", $text{'config_dirto'};
$rv .= sprintf "<input name=add_dir size=30 value='%s'>\n", $_[0];
return $rv;
}

sub parse_add_dir
{
return $in{'add_dir_def'} ? undef : $in{'add_dir'};
}

