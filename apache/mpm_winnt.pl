# mpm_winnt.pl
# Defines editors for the windows NT module in apache 2.0
# The actual functions for most of these are still in core.pl

sub mpm_winnt_directives
{
local $rv;
$rv = [ [ 'CoreDumpDirectory', 0, 9, 'global', 2.0 ],
	[ 'BindAddress Listen Port', 1, 1, 'global', 2.0, 10 ],
	[ 'ListenBacklog', 0, 1, 'global', 2.0 ],
	[ 'MaxRequestsPerChild', 0, 0, 'global', 2.0 ],
	[ 'PidFile', 0, 9, 'global', 2.0 ],
	[ 'SendBufferSize', 0, 1, 'global', 2.0 ],
	[ 'ThreadsPerChild', 0, 0, 'global', 2.0 ] ];
return &make_directives($rv, $_[0], "mpm_winnt");
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

