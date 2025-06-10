# mod_cache.pl
# Functions that have been moved out of mod_proxy in apache 2.0

sub mod_cache_directives
{
local $rv;
$rv = [ [ 'CacheDefaultExpire', 0, 13.1, 'virtual', 2.0 ],
	[ 'CacheEnable CacheDisable', 1, 13.1, 'virtual', 2.0 ],
#	[ 'CacheIgnoreCacheControl', 0, 13.1, 'virtual', 2.0 ],
#	[ 'CacheIgnoreNoLastMod', 0, 13.1, 'virtual', 2.0 ],
        [ 'CacheLastModifiedFactor', 0, 13.1, 'virtual', 2.0 ],
	[ 'CacheMaxExpire', 0, 13.1, 'virtual', 2.0 ] ];
return &make_directives($rv, $_[0], "mod_cache");
}

require 'cache.pl';

sub edit_CacheEnable_CacheDisable
{
local $rv = "<table border>\n".
	    "<tr $tb> <td><b>$text{'cache_enable'}</b></td>\n".
	    "<td><b>$text{'cache_type'}</b></td>\n".
	    "<td><b>$text{'cache_url'}</b></td> </tr>\n";
local ($c, $i = 0);
foreach $c (@{$_[0]}, @{$_[1]}, { }) {
	$rv .= "<tr $cb>\n";
	$rv .= "<td><select name=CacheEnable_e_$i>\n";
	$rv .= sprintf "<option value=0 %s>&nbsp;</option>\n",
			$c ? "" : "selected";
	$rv .= sprintf "<option value=1 %s>%s</option>\n",
			$c->{'name'} eq 'CacheEnable' ? 'selected' : '',
			$text{'yes'};
	$rv .= sprintf "<option value=2 %s>%s</option>\n",
			$c->{'name'} eq 'CacheDisable' ? 'selected' : '',
			$text{'no'};
	$rv .= "</select></td> <td><select name=CacheEnable_t_$i>\n";
	$rv .= sprintf "<option value=disk %s>%s</option>\n",
			$c->{'words'}->[0] eq 'disk' ? 'selected' : '',
			$text{'cache_disk'};
	$rv .= sprintf "<option value=mem %s>%s</option>\n",
			$c->{'words'}->[0] eq 'mem' ? 'selected' : '',
			$text{'cache_mem'};
	$rv .= "</select></td>\n";
	$rv .= sprintf "<td><input name=CacheEnable_u_$i size=20 value='%s'></td>\n", $c->{'name'} eq 'CacheEnable' ? $c->{'words'}->[1] : $c->{'words'}->[0];
	$rv .= "</tr>\n";
	$i++;
	}
$rv .= "</table>\n";
return (2, $text{'cache_endis'}, $rv);
}
sub save_CacheEnable_CacheDisable
{
local ($i, @en, @dis);
for($i=0; defined($in{"CacheEnable_e_$i"}); $i++) {
	next if (!$in{"CacheEnable_e_$i"});
	$in{"CacheEnable_u_$i"} =~ /^\S+$/ || &error($text{'cache_eurl'});
	if ($in{"CacheEnable_e_$i"} == 1) {
		push(@en, $in{"CacheEnable_t_$i"}." ".$in{"CacheEnable_u_$i"});
		}
	else {
		push(@dis, $in{"CacheEnable_u_$i"});
		}
	}
return ( \@en, \@dis );
}

sub edit_CacheIgnoreCacheControl
{
return (1, $text{'cache_control'},
        &choice_input($_[0]->{'value'}, "CacheIgnoreCacheControl", "off",
                      "$text{'yes'},on", "$text{'no'},off"));
}
sub save_CacheIgnoreCacheControl
{
return &parse_choice("CacheIgnoreCacheControl", "off");
}

sub edit_CacheIgnoreNoLastMod
{
return (1, $text{'cache_lastmod'},
        &choice_input($_[0]->{'value'}, "CacheIgnoreNoLastMod", "off",
                      "$text{'yes'},on", "$text{'no'},off"));
}
sub save_CacheIgnoreNoLastMod
{
return &parse_choice("CacheIgnoreNoLastMod", "off");
}

