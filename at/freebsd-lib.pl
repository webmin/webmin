# freebsd-lib.pl

sub list_atjobs
{
local @rv;
opendir(DIR, $config{'at_dir'});
while($f = readdir(DIR)) {
	local $p = "$config{'at_dir'}/$f";
	if ($f =~ /^c(\S{5})(\S+)$/) {
		local @st = stat($p);
		local $job = { 'id' => hex($1),
			       'date' => hex($2) * 60,
			       'user' => scalar(getpwuid($st[4])),
			       'created' => $st[9] };
		open(FILE, $p);
		while(<FILE>) {
			$job->{'cmd'} .= $_;
			}
		close(FILE);
		$job->{'realcmd'} = $job->{'cmd'};
		$job->{'realcmd'} =~ s/^[\000-\177]+cd\s+(\S+)\s+\|\|\s+{\n.*\n.*\n.*\n//;
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
local $date = sprintf "%2.2d:%2.2d %d.%d.%d",
		$tm[2], $tm[1], $tm[3], $tm[4]+1, $tm[5]+1900;
local $cmd = "cd ".quotemeta($_[3])." ; at $date";
local @uinfo = getpwnam($_[0]);
if ($uinfo[2] != $<) {
	# Only SU if we are not already the user
	$cmd = &command_as_user($_[0], 0, $cmd);
	}
&open_execute_command(AT, "$cmd >/dev/null 2>&1", 0); 
print AT $_[2];
close(AT);
&additional_log('exec', undef, "su \"$_[0]\" -c \"cd $_[3] ; at $date\"");
}

# delete_atjob(id)
sub delete_atjob
{
&system_logged("atrm ".quotemeta($_[0])." >/dev/null 2>&1");
}

