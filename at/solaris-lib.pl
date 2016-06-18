# solaris-lib.pl
use strict;
use warnings;
our %config;

use POSIX;

sub list_atjobs
{
my @rv;
opendir(my $DIR, $config{'at_dir'});
while(my $f = readdir($DIR)) {
	my $p = "$config{'at_dir'}/$f";
	if ($f =~ /^(\d+)\.a$/) {
		my @st = stat($p);
		my $job = { 'id' => $f,
			       'date' => $1,
			       'user' => scalar(getpwuid($st[4])),
			       'created' => $st[9] };
		open(my $FILE, "<", $p);
		while(<$FILE>) {
			$job->{'cmd'} .= $_;
			}
		close($FILE);
		$job->{'realcmd'} = $job->{'cmd'};
		$job->{'realcmd'} =~ s/^[\000-\177]+#ident.*\ncd\s+\S+\numask\s+\S+\n//;
		$job->{'realcmd'} =~ s/^ulimit\s+\S+\n//;
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
my $date = strftime "%H:%M %b %d", @tm;
my $mailflag = $_[4] ? "-m" : "";
my $cmd = "cd ".quotemeta($_[3])." ; at $mailflag $date";
my @uinfo = getpwnam($_[0]);
if ($uinfo[2] != $<) {
	# Only SU if we are not already the user
	$cmd = &command_as_user($_[0], 0, $cmd);
	}
no strict "subs";
&open_execute_command(AT, "$cmd >/dev/null 2>&1", 0); 
print AT $_[2];
close(AT);
use strict "subs";
&additional_log('exec', undef, $cmd);
}

# delete_atjob(id)
sub delete_atjob
{
&system_logged("atrm ".quotemeta($_[0]));
}

