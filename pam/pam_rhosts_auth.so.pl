# display args for pam_rhosts_auth.so

# display_args(&service, &module, &args)
sub display_module_args
{
print &ui_table_row($text{'rhosts_equiv'},
	&ui_radio("equiv", defined($_[2]->{'no_hosts_equiv'}) ? 1 : 0,
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

print &ui_table_row($text{'rhosts_rhosts'},
	&ui_radio("rhosts", defined($_[2]->{'no_hosts'}) ? 1 : 0,
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

print &ui_table_row($text{'rhosts_promiscuous'},
	&ui_yesno_radio("promiscuous",defined($_[2]->{'promiscuous'}) ? 1 : 0));

print &ui_table_row($text{'rhosts_suppress'},
	&ui_radio("suppress", defined($_[2]->{'supress'}) ? 1 : 0,
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
if ($in{'equiv'}) { $_[2]->{'no_hosts_equiv'} = ''; }
else { delete($_[2]->{'no_hosts_equiv'}); }

if ($in{'rhosts'}) { $_[2]->{'no_rhosts'} = ''; }
else { delete($_[2]->{'no_rhosts'}); }

if ($in{'promiscuous'}) { $_[2]->{'promiscuous'} = ''; }
else { delete($_[2]->{'promiscuous'}); }

if ($in{'suppress'}) { $_[2]->{'suppress'} = ''; }
else { delete($_[2]->{'suppress'}); }
}
