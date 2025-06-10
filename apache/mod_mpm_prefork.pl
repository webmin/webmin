# mod_mpm_prefork.pl
# Defines editors for the pre-forking module in apache 2.4.
# The actual functions for all of these are still in core.pl

sub mod_mpm_prefork_directives
{
local $rv;
$rv = [ [ 'CoreDumpDirectory', 0, 9, 'global', 2.0 ],
	[ 'BindAddress Listen Port', 1, 1, 'global', 2.0, 10 ],
	[ 'ListenBacklog', 0, 1, 'global', 2.0 ],
	[ 'LockFile', 0, 9, 'global', 2.0 ],
	[ 'MaxRequestsPerChild', 0, 0, 'global', 2.0 ],
	[ 'MinSpareServers', 0, 0, 'global', 2.0 ],
	[ 'MaxSpareServers', 0, 0, 'global', 2.0 ],
	[ 'PidFile', 0, 9, 'global', 2.0 ],
	[ 'ScoreBoardFile', 0, 9, 'global', 2.0 ],
	[ 'SendBufferSize', 0, 1, 'global', 2.0 ],
	[ 'StartServers', 0, 0, 'global', 2.0 ],
	[ 'Group', 0, 8, 'global', 2.0 ],
	[ 'User', 0, 8, 'global', 2.0, 10 ] ];
return &make_directives($rv, $_[0], "mod_mpm_prefork");
}


