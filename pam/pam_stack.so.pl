# display args for pam_stack

# display_args(&service, &module, &args)
sub display_module_args
{
print &ui_table_row($text{'stack_service'},
    &ui_select("service", $_[2]->{'service'},
	[ map { [ $_->{'name'},
		  $_->{'name'}.($text{'desc_'.$_->{'name'}} ?
				" (".$text{'desc_'.$_->{'name'}}.")" : "") ] }
	      &get_pam_config() ],
	1, 0, $_[2]->{'service'} ? 1 : 0), 3);
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
$_[2]->{'service'} = $in{'service'};
}
