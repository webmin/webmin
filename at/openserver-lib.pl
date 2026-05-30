# openserver-lib.pl

use POSIX;
no warnings "redefine";

sub list_atjobs
{
my @rv;
opendir(DIR, $config{'at_dir'}) || return ();
while($f = readdir(DIR)) {
	my $p = "$config{'at_dir'}/$f";
	if ($f =~ /^(\d+)\.a(\S+)$/) {
		my @st = stat($p);
		my $job = { 'id' => $f,
			       'date' => $1,
			       'user' => scalar(getpwuid($st[4])),
			       'created' => $st[9] };
		open(FILE, "<".$p);
		while(<FILE>) {
			$job->{'cmd'} .= $_;
			}
		close(FILE);
		$job->{'realcmd'} = $job->{'cmd'};
		$job->{'realcmd'} =~ s/^[\000-\177]+#ident.*\ncd\s+\S+\nulimit\s+\S+\numask\s+\S+\n//;
		push(@rv, $job);
		}
	}
closedir(DIR);
return @rv;
}

# create_atjob(user, time, commands, directory)
sub create_atjob
{
my ($user, $tm, $cmds, $dir) = @_;
my @tm = localtime($tm);
my $date = strftime "%H:%M %b %d", @tm;
my $fullcmd = &command_as_user($user, 0, "cd $dir ; at $date");
&open_execute_command(AT, $fullcmd, 0); 
print AT $cmds;
close(AT);
&additional_log('exec', undef, $fullcmd);
}

# delete_atjob(id)
sub delete_atjob
{
my ($id) = @_;
&system_logged("at -r ".quotemeta($id));
}

