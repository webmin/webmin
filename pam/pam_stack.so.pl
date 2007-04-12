# display args for pam_stack

# display_args(&service, &module, &args)
sub display_module_args
{
print "<tr> <td><b>$text{'stack_service'}</b></td>\n";
print "<td><select name=service>\n";
local $found;
foreach $c (&get_pam_config()) {
	printf "<option value=%s %s>%s\n",
		$c->{'name'},
		$_[2]->{'service'} eq $c->{'name'} ? 'selected' : '',
		$text{"desc_".$c->{'name'}} ? $text{"desc_".$c->{'name'}}
					    : $c->{'name'};
	$found++ if ($_[2]->{'service'} eq $c->{'name'});
	}
if ($_[2]->{'service'} && !$found) {
	print "<option checked>$_[2]->{'service'}\n";
	}
print "</select></td> </tr>\n";
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
$_[2]->{'service'} = $in{'service'};
}
