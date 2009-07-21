# mod_disk_cache.pl
# Disk-caching related functions

sub mod_disk_cache_directives
{
local $rv;
$rv = [ [ 'CacheRoot', 0, 13.1, 'virtual', 2.0 ],
        [ 'CacheSize', 0, 13.1, 'virtual', 2.0 ],
        [ 'CacheGcInterval', 0, 13.1, 'virtual', 2.0 ],
        [ 'CacheDirLevels', 0, 13.1, 'virtual', 2.0 ],
        [ 'CacheDirLength', 0, 13.1, 'virtual', 2.0 ],
	[ 'CacheMinFileSize', 0, 13.1, 'virtual', 2.0 ],
	[ 'CacheMaxFileSize', 0, 13.1, 'virtual', 2.0 ] ];
return &make_directives($rv, $_[0], "mod_disk_cache");
}

require 'cache.pl';

sub edit_CacheMinFileSize
{
return (1, $text{'cache_minfs'},
	&opt_input($_[0]->{'value'}, "CacheMinFileSize", $text{'default'}, 8));
}
sub save_CacheMinFileSize
{
return &parse_opt("CacheMinFileSize", '^\d+$', $text{'cache_eminfs'});
}

sub edit_CacheMaxFileSize
{
return (1, $text{'cache_maxfs'},
	&opt_input($_[0]->{'value'}, "CacheMaxFileSize", $text{'default'}, 8));
}
sub save_CacheMaxFileSize
{
return &parse_opt("CacheMaxFileSize", '^\d+$', $text{'cache_emaxfs'});
}

# XXX new stuff in mod_proxy

