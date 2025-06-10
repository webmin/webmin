# worker.pl
# Defines editors for the fork/thread module in apache 2.0
# The actual functions for most of these are still in core.pl

sub worker_directives
{
local $rv;
$rv = [ [ 'CoreDumpDirectory', 0, 9, 'global', 2.0 ],
	[ 'BindAddress Listen Port', 1, 1, 'global', 2.0, 10 ],
	[ 'ListenBacklog', 0, 1, 'global', 2.0 ],
	[ 'LockFile', 0, 9, 'global', 2.0 ],
	[ 'MaxClients', 0, 0, 'global', 2.0 ],
	[ 'MaxRequestsPerChild', 0, 0, 'global', 2.0 ],
	[ 'MinSpareThreads', 0, 0, 'global', 2.0 ],
	[ 'MaxSpareThreads', 0, 0, 'global', 2.0 ],
	[ 'PidFile', 0, 9, 'global', 2.0 ],
	[ 'ScoreBoardFile', 0, 9, 'global', 2.0 ],
	[ 'SendBufferSize', 0, 1, 'global', 2.0 ],
	[ 'StartServers', 0, 0, 'global', 2.0 ],
	[ 'ThreadsPerChild', 0, 0, 'global', 2.0 ],
	[ 'Group', 0, 8, 'global', 2.0 ],
	[ 'User', 0, 8, 'global', 2.0, 10 ] ];
return &make_directives($rv, $_[0], "worker");
}

sub edit_MinSpareThreads
{
return (1,
	$text{'worker_minspare'},
	&opt_input($_[0]->{'value'},"MinSpareThreads",$text{'default'}, 4));
}
sub save_MinSpareThreads
{
return &parse_opt("MinSpareThreads", '^\d+$',
		  $text{'worker_eminspare'});
}

sub edit_MaxSpareThreads
{
return (1,
	$text{'worker_maxspare'},
	&opt_input($_[0]->{'value'},"MaxSpareThreads",$text{'default'}, 4));
}
sub save_MaxSpareThreads
{
return &parse_opt("MaxSpareThreads", '^\d+$',
		  $text{'worker_emaxspare'});
}

sub edit_ThreadsPerChild
{
return (1,
	$text{'worker_threads'},
	&opt_input($_[0]->{'value'},"ThreadsPerChild",$text{'default'}, 4));
}
sub save_ThreadsPerChild
{
return &parse_opt("ThreadsPerChild", '^\d+$',
		  $text{'worker_ethreads'});
}

