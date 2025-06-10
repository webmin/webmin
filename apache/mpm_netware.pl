# mpm_netware.pl
# Defines editors for the netware module in apache 2.0
# The actual functions for most of these are still in core.pl

sub mpm_netware_directives
{
local $rv;
$rv = [ [ 'BindAddress Listen Port', 1, 1, 'global', 2.0, 10 ],
	[ 'ListenBacklog', 0, 1, 'global', 2.0 ],
	[ 'MaxRequestsPerChild', 0, 0, 'global', 2.0 ],
	[ 'MinSpareThreads', 0, 0, 'global', 2.0 ],
	[ 'MaxSpareThreads', 0, 0, 'global', 2.0 ],
	[ 'SendBufferSize', 0, 1, 'global', 2.0 ],
	[ 'StartThreads', 0, 0, 'global', 2.0 ] ];
return &make_directives($rv, $_[0], "mpm_netware");
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

sub edit_StartThreads
{
return (1,
	$text{'perchild_sthreads'},
	&opt_input($_[0]->{'value'},"StartThreads",$text{'default'}, 4));
}
sub save_StartThreads
{
return &parse_opt("StartThreads", '^\d+$',
		  $text{'perchild_esthreads'});
}


