# perchild.pl
# Defines editors for the per-child UID module in apache 2.0
# The actual functions for most of these are still in core.pl

sub perchild_directives
{
local $rv;
$rv = [ [ 'AssignUserId', 0, 8, 'virtual virtualonly', 2.0 ],
	[ 'ChildPerUserId', 1, 8, 'global', 2.0 ],
	[ 'CoreDumpDirectory', 0, 9, 'global', 2.0 ],
	[ 'BindAddress Listen Port', 1, 1, 'global', 2.0, 10 ],
	[ 'ListenBacklog', 0, 1, 'global', 2.0 ],
	[ 'LockFile', 0, 9, 'global', 2.0 ],
	[ 'MaxRequestsPerChild', 0, 0, 'global', 2.0 ],
	[ 'MinSpareThreads', 0, 0, 'global', 2.0 ],
	[ 'MaxSpareThreads', 0, 0, 'global', 2.0 ],
	[ 'MaxThreadsPerChild', 0, 0, 'global', 2.0 ],
	[ 'NumServers', 0, 0, 'global', 2.0 ],
	[ 'PidFile', 0, 9, 'global', 2.0 ],
	[ 'ScoreBoardFile', 0, 9, 'global', 2.0 ],
	[ 'SendBufferSize', 0, 1, 'global', 2.0 ],
	[ 'StartThreads', 0, 0, 'global', 2.0 ],
	[ 'Group', 0, 8, 'global', 2.0, 9 ],
	[ 'User', 0, 8, 'global', 2.0, 10 ] ];
return &make_directives($rv, $_[0], "perchild");
}

sub edit_AssignUserId
{
local $rv;
$rv .= sprintf "<input type=radio name=AssignUserId_def value=1 %s> %s\n",
		$_[0] ? "" : "checked", $text{'core_none'};
$rv .= sprintf "<input type=radio name=AssignUserId_def value=0 %s>\n",
		$_[0] ? "checked" : "";
$rv .= &text('perchild_assignug',
	"<input name=AssignUserId_uid size=8 value='$_[0]->{'words'}->[0]'>",
	"<input name=AssignUserId_gid size=8 value='$_[0]->{'words'}->[1]'>");
return (2, $text{'perchild_assign'}, $rv);
}
sub save_AssignUserId
{
if ($in{'AssignUserId_def'}) {
	return ( [ ] );
	}
else {
	$in{'AssignUserId_uid'} =~ /^-?\d+$/ || &error($text{'perchild_euid'});
	$in{'AssignUserId_gid'} =~ /^-?\d+$/ || &error($text{'perchild_egid'});
	return ( [ "$in{'AssignUserId_uid'} $in{'AssignUserId_gid'}" ] );
	}
}

sub edit_ChildPerUserId
{
local $rv = "<table border>\n".
	    "<tr $tb> <td><b>$text{'perchild_num'}</b></td>\n".
	    "<td><b>$text{'perchild_uid'}</b></td>\n".
	    "<td><b>$text{'perchild_gid'}</b></td> </tr>\n";
local ($c, $i = 0);
foreach $c (@{$_[0]}, undef) {
	local @v = $c ? @{$c->{'words'}} : ();
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input name=ChildPerUserId_n_$i size=5 value='$v[2]'></td>\n";
	$rv .= "<td><input name=ChildPerUserId_u_$i size=8 value='$v[0]'></td>\n";
	$rv .= "<td><input name=ChildPerUserId_g_$i size=8 value='$v[1]'></td>\n";
	$rv .= "</tr>\n";
	$i++;
	}
$rv .= "</table>\n";
return (2, $text{'perchild_child'}, $rv);
}
sub save_ChildPerUserId
{
local (@rv, $i);
for($i=0; defined($in{"ChildPerUserId_n_$i"}); $i++) {
	next if (!$in{"ChildPerUserId_n_$i"});
	$in{"ChildPerUserId_n_$i"} =~ /^[1-9]\d*$/ ||
		&error($text{'perchild_enum'});
	$in{"ChildPerUserId_u_$i"} =~ /^-?\d+$/ ||
		&error($text{'perchild_euid'});
	$in{"ChildPerUserId_g_$i"} =~ /^-?\d+$/ ||
		&error($text{'perchild_egid'});
	push(@rv, $in{"ChildPerUserId_u_$i"}." ".$in{"ChildPerUserId_g_$i"}." ".
		  $in{"ChildPerUserId_n_$i"});
	}
return ( \@rv );
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

sub edit_NumServers
{
return (1,
	$text{'perchild_numservers'},
	&opt_input($_[0]->{'value'},"NumServers",$text{'default'}, 4));
}
sub save_NumServers
{
return &parse_opt("NumServers", '^\d+$',
		  $text{'perchild_enumservers'});
}

sub edit_MaxThreadsPerChild
{
return (1,
	$text{'perchild_maxthreads'},
	&opt_input($_[0]->{'value'},"MaxThreadsPerChild",$text{'default'}, 4));
}
sub save_MaxThreadsPerChild
{
return &parse_opt("MaxThreadsPerChild", '^\d+$',
		  $text{'perchild_emaxthreads'});
}
