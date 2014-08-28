# Functions for FreeBSD pkg repository

sub list_update_system_commands
{
return ("pkg");
}

# update_system_install([package], [&in], [no-force])
# Install some package with apt
sub update_system_install
{
my $update = $_[0] || $in{'update'};
my $in = $_[1];
my $force = !$_[2];

# Build and show command to run
$update = join(" ", map { quotemeta($_) } split(/\s+/, $update));
my $cmd = "pkg install ".$update;
print "<b>",&text('pkg_install', "<tt>$cmd</tt>"),"</b><p>\n";
print "<pre>";
&additional_log('exec', undef, $cmd);

# Run it
&open_execute_command(CMD, $cmd, 2);
while(<CMD>) {
	if (/Installing\s+(\S+)\-(\d\S*)/i) {
		push(@rv, $1);
		}
	print &html_escape("$_");
	}
close(CMD);

print "</pre>\n";
if ($?) { print "<b>$text{'pkg_failed'}</b><p>\n"; }
else { print "<b>$text{'pkg_ok'}</b><p>\n"; }
return @rv;
}


1;
