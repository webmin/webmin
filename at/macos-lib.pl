# macos-lib.pl
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
no warnings "redefine";
our %config;

sub list_atjobs
{
my @rv;
opendir(my $DIR, $config{'at_dir'}) || return ();
while(my $f = readdir($DIR)) {
	my $p = "$config{'at_dir'}/$f";
	if ($f =~ /^a(\S+)\.(\d+)$/) {
		my @st = stat($p);
		my $job = { 'id' => $f,
			       'date' => hex($1)*60,
			       'user' => scalar(getpwuid($st[4])),
			       'created' => $st[9] };
		open(my $FILE, "<", $p);
		while(<$FILE>) {
			$job->{'cmd'} .= $_;
			}
		close($FILE);
		$job->{'realcmd'} = $job->{'cmd'};
		$job->{'realcmd'} =~ s/^[\000-\177]+cd\s+(\S+)\n//;
		push(@rv, $job);
		}
	}
closedir($DIR);
return @rv;
}

# create_atjob(user, time, commands, directory, send-email)
sub create_atjob
{
my ($user, $tm, $cmds, $dir, $email) = @_;
my @tm = localtime($tm);
my $date = sprintf "%2.2d:%2.2d %d.%d.%d",
		$tm[2], $tm[1], $tm[3], $tm[4]+1, $tm[5]+1900;
my $mailflag = $email ? "-m" : "";
no strict "subs";
my $fullcmd = &command_as_user($user, 0, "cd $dir ; at $mailflag $date");
&open_execute_command(AT, "$fullcmd >/dev/null 2>&1", 0); 
print AT $cmds;
close(AT);
use strict "subs";
&additional_log('exec', undef, $fullcmd);
}

# delete_atjob(id)
sub delete_atjob
{
my ($id) = @_;
&system_logged("atrm ".quotemeta($id)." >/dev/null 2>&1");
}

