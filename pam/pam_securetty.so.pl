# display args for pam_securetty.so.pl

# display_args(&service, &module, &args)
sub display_module_args
{
local $file = "/etc/securetty";
print &ui_table_row($text{'securetty_ttys'},
	&ui_textarea("ttys", &read_file_contents($file), 5, 40), 3);
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
local $file = "/etc/securetty";
&lock_file($file);
&open_tempfile(FILE, ">$file");
$in{'ttys'} =~ s/\r//g;
$in{'ttys'} =~ s/\s*$/\n/;
&print_tempfile(FILE, $in{'ttys'});
&close_tempfile(FILE);
&unlock_file($file);
}
