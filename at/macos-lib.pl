# macos-lib.pl
use strict;
use warnings;
our %config;

sub list_atjobs
{
my @rv;
opendir(my $DIR, $config{'at_dir'});
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
my @tm = localtime($_[1]);
my $date = sprintf "%2.2d:%2.2d %d.%d.%d",
		$tm[2], $tm[1], $tm[3], $tm[4]+1, $tm[5]+1900;
my $mailflag = $_[4] ? "-m" : "";
no strict "subs";
&open_execute_command(AT, "su \"$_[0]\" -c \"cd $_[3] ; at $mailflag $date\" >/dev/null 2>&1", 0); 
print AT $_[2];
close(AT);
use strict "subs";
&additional_log('exec', undef, "su \"$_[0]\" -c \"cd $_[3] ; at $mailflag $date\"");
}

# delete_atjob(id)
sub delete_atjob
{
&system_logged("atrm \"$_[0]\" >/dev/null 2>&1");
}

