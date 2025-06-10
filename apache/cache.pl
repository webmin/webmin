# cache.pl
# Functions used by both mod_proxy.pl and the new apache caching modules

sub edit_CacheRoot
{
return (1, $text{'mod_proxy_dir'},
        &opt_input($_[0]->{'value'}, "CacheRoot", $text{'mod_proxy_none'}, 20).
        &file_chooser_button("CacheRoot", 0));
}
sub save_CacheRoot
{
$in{'CacheRoot_def'} || &allowed_auth_file($in{'CacheRoot'}) ||
	&error($text{'mod_proxy_eunder'});
return &parse_opt("CacheRoot", '^\S+$', $text{'mod_proxy_edir'});
}

sub edit_CacheSize
{
return (1, $text{'mod_proxy_size'},
        &opt_input($_[0]->{'value'}, "CacheSize", $text{'mod_proxy_default'}, 8)." kB");
}
sub save_CacheSize
{
return &parse_opt("CacheSize", '^\d+$', $text{'mod_proxy_esize'});
}

sub edit_CacheGcInterval
{
return (1, $text{'mod_proxy_garbage'},
        &opt_input($_[0]->{'value'}, "CacheGcInterval", $text{'mod_proxy_nogc'}, 6).
	$text{'mod_proxy_hours'});
}
sub save_CacheGcInterval
{
return &parse_opt("CacheGcInterval", '^\d+$',
                  $text{'mod_proxy_egarbage'});
}

sub edit_CacheMaxExpire
{
return (1, $text{'mod_proxy_maxexp'},
        &opt_input($_[0]->{'value'}, "CacheMaxExpire", $text{'mod_proxy_default'}, 6).
	$text{'mod_proxy_seconds'});
}
sub save_CacheMaxExpire
{
return &parse_opt("CacheMaxExpire", '^\d+$',
                  $text{'mod_proxy_emaxexp'});
}

sub edit_CacheLastModifiedFactor
{
return (1, $text{'mod_proxy_expfac'},
        &opt_input($_[0]->{'value'}, "CacheLastModifiedFactor", $text{'mod_proxy_default'}, 6));
}
sub save_CacheLastModifiedFactor
{
return &parse_opt("CacheLastModifiedFactor", '^\d+$',
                  $text{'mod_proxy_eexpfac'});
}

sub edit_CacheDirLevels
{
return (1, $text{'mod_proxy_levels'},
        &opt_input($_[0]->{'value'}, "CacheDirLevels", $text{'mod_proxy_default'}, 6));
}
sub save_CacheDirLevels
{
return &parse_opt("CacheDirLevels", '^\d+$',
                  $text{'mod_proxy_elevels'});
}

sub edit_CacheDirLength
{
return (1, $text{'mod_proxy_length'},
        &opt_input($_[0]->{'value'}, "CacheDirLength", $text{'mod_proxy_default'}, 4));
}
sub save_CacheDirLength
{
return &parse_opt("CacheDirLength", '^\d+$',
                  $text{'mod_proxy_elength'});
}

sub edit_CacheDefaultExpire
{
return (1, $text{'mod_proxy_defexp'},
        &opt_input($_[0]->{'value'}, "CacheDefaultExpire", $text{'mod_proxy_default'}, 6).
	$text{'mod_proxy_seconds'});
}
sub save_CacheDefaultExpire
{
return &parse_opt("CacheDefaultExpire", '^\d+$', $text{'mod_proxy_edefexp'});
}

sub edit_CacheForceCompletion
{
return (1, $text{'mod_proxy_finish'},
        &opt_input($_[0]->{'value'}, "CacheForceCompletion", $text{'mod_proxy_default'}, 6)."%");
}
sub save_CacheForceCompletion
{
return &parse_opt("CacheForceCompletion", '^\d+$',
		  $text{'mod_proxy_efinish'});
}

sub edit_NoCache
{
local($n, @n);
foreach $n (@{$_[0]}) { push(@n, $n->{'value'}); }
return (1, $text{'mod_proxy_nocache'},
        &opt_input(@n ? join(' ', @n) : undef, "NoCache", $text{'mod_proxy_none2'}, 20));
}
sub save_NoCache
{
return &parse_opt("NoCache", '\S', $text{'mod_proxy_enocache'});
}

1;

