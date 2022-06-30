# linux-lib.pl
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
no warnings "redefine";
our (%config);

sub list_atjobs
{
my @rv;
opendir(my $DIR, $config{'at_dir'}) || return ();
while(my $f = readdir($DIR)) {
	my $p = "$config{'at_dir'}/$f";
	if ($f =~ /^a(\S{5})(\S+)$/) {
		my @st = stat($p);
		my $job = { 'id' => hex($1),
			       'date' => hex($2) * 60,
			       'user' => scalar(getpwuid($st[4])),
			       'created' => $st[9] };
		open(my $FILE, "<", $p);
		while(<$FILE>) {
			$job->{'cmd'} .= $_;
			}
		close($FILE);
		$job->{'realcmd'} = $job->{'cmd'};
		$job->{'realcmd'} =~ s/^[\000-\177]+cd\s+(\S+)\s+\|\|\s+{\n.*\n.*\n.*\n//;
		$job->{'realcmd'} =~ s/\$\{SHELL:.*\n\n?//;
		push(@rv, $job);
		}
	}
closedir($DIR);
return @rv;
}

# create_atjob(user, time, command, directory, send-email)
# Create a new at job that runs the given command at the given time
sub create_atjob
{
my ($user, $attime, $cmd, $dir, $email) = @_;
my @tm = localtime($attime);
my $date = sprintf "%2.2d:%2.2d %d.%d.%d",
		$tm[2], $tm[1], $tm[3], $tm[4]+1, $tm[5]+1900;
my $mailflag = $email ? "-m" : "";
my $atcmd = "cd ".quotemeta($dir)." ; at $mailflag $date";
my @uinfo = getpwnam($user);
if ($uinfo[2] != $<) {
	# Only SU if we are not already the user
	$atcmd = &command_as_user($user, 0, $atcmd);
	}
no strict "subs";
&open_execute_command(AT, "$atcmd >/dev/null 2>&1", 0);
print AT $cmd,"\n";
close(AT);
use strict "subs";
&additional_log('exec', undef, $atcmd);
}

# delete_atjob(id)
sub delete_atjob
{
&system_logged("atrm ".quotemeta($_[0])." >/dev/null 2>&1");
}

# get_init_name()
# Returns the name of the bootup action for atd, if there is one
sub get_init_name
{
&foreign_require("init");
if (&init::action_status("atd") != 0) {
	return "atd";
	}
return undef;
}

