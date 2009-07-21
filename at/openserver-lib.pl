# openserver-lib.pl

use POSIX;

sub list_atjobs
{
local @rv;
opendir(DIR, $config{'at_dir'});
while($f = readdir(DIR)) {
	local $p = "$config{'at_dir'}/$f";
	if ($f =~ /^(\d+)\.a(\S+)$/) {
		local @st = stat($p);
		local $job = { 'id' => $f,
			       'date' => $1,
			       'user' => scalar(getpwuid($st[4])),
			       'created' => $st[9] };
		open(FILE, $p);
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
local @tm = localtime($_[1]);
local $date = strftime "%H:%M %b %d", @tm;
&open_execute_command(AT, "su \"$_[0]\" -c \"cd $_[3] ; at $date\"", 0); 
print AT $_[2];
close(AT);
&additional_log('exec', undef, "su \"$_[0]\" -c \"cd $_[3] ; at $date\"");
}

# delete_atjob(id)
sub delete_atjob
{
&system_logged("at -r \"$_[0]\"");
}

