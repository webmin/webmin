# display args for pam_shells.so.pl

# display_args(&service, &module, &args)
sub display_module_args
{
local $file = "/etc/shells";
print &ui_table_row($text{'shells_shells'},
	&ui_textarea("shells", &read_file_contents($file), 5, 40), 3);
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
local $file = "/etc/shells";
&lock_file($file);
&open_tempfile(FILE, ">$file");
$in{'shells'} =~ s/\r//g;
$in{'shells'} =~ s/\s*$/\n/;
&print_tempfile(FILE, $in{'shells'});
&close_tempfile(FILE);
&unlock_file($file);
}
