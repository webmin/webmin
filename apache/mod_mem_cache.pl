# mod_mem_cache.pl
# Memory-caching related functions

sub mod_mem_cache_directives
{
local $rv;
$rv = [ [ 'CacheSize', 0, 13.1, 'virtual', 2.0 ],
	[ 'CacheMaxObjectCount', 0, 13.1, 'virtual', 2.0 ],
	[ 'CacheMinObjectSize', 0, 13.1, 'virtual', 2.0 ],
	[ 'CacheMaxObjectSize', 0, 13.1, 'virtual', 2.0 ] ];
return &make_directives($rv, $_[0], "mod_mem_cache");
}

require 'cache.pl';

sub edit_CacheMaxObjectCount
{
return (1, $text{'cache_maxoc'},
	&opt_input($_[0]->{'value'}, "CacheMaxObjectCount", $text{'default'},8));
}
sub save_CacheMaxObjectCount
{
return &parse_opt("CacheMaxObjectCount", '^\d+$', $text{'cache_emaxoc'});
}

sub edit_CacheMinObjectSize
{
return (1, $text{'cache_minos'},
	&opt_input($_[0]->{'value'}, "CacheMinObjectSize", $text{'default'},8));
}
sub save_CacheMinObjectSize
{
return &parse_opt("CacheMinObjectSize", '^\d+$', $text{'cache_eminos'});
}

sub edit_CacheMaxObjectSize
{
return (1, $text{'cache_maxos'},
	&opt_input($_[0]->{'value'}, "CacheMaxObjectSize", $text{'default'},8));
}
sub save_CacheMaxObjectSize
{
return &parse_opt("CacheMaxObjectSize", '^\d+$', $text{'cache_emaxos'});
}


