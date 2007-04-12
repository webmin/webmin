# display args for pam_securetty.so.pl

# display_args(&service, &module, &args)
sub display_module_args
{
local $file = "/etc/securetty";
print "<tr> <td valign=top><b>$text{'securetty_ttys'}</b></td>\n";
print "<td><textarea name=ttys rows=5 cols=20>";
open(FILE, $file);
while(<FILE>) { print; }
close(FILE);
print "</textarea></td> </tr>\n";
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
