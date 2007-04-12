# display args for pam_shells.so.pl

# display_args(&service, &module, &args)
sub display_module_args
{
local $file = "/etc/shells";
print "<tr> <td valign=top><b>$text{'shells_shells'}</b></td>\n";
print "<td><textarea name=shells rows=5 cols=30>";
open(FILE, $file);
while(<FILE>) { print; }
close(FILE);
print "</textarea></td> </tr>\n";
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
