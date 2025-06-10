# mod_vhost_alias.pl
# Defines editors for vhost_alias module directives

sub mod_vhost_alias_directives
{
$rv = [ [ 'VirtualDocumentRoot VirtualDocumentRootIP', 0, 17, 'virtual', 1.307 ],
	[ 'VirtualScriptAlias VirtualScriptAliasIP', 0, 17, 'virtual', 1.307 ] ];
return &make_directives($rv, $_[0], "mod_vhost_alias");
}

sub edit_VirtualDocumentRoot_VirtualDocumentRootIP
{
local $rv;

$rv = sprintf "<input type=radio name=VirtualDocumentRoot_def value=1 %s> %s\n",
	$_[0] || $_[1] ? '' : 'checked', $text{'mod_vhost_alias_none'};
$rv .= sprintf "<input type=radio name=VirtualDocumentRoot_def value=0 %s>\n",
	$_[0] || $_[1] ? 'checked' : '';
$rv .= sprintf "<input name=VirtualDocumentRoot size=50 value='%s'><br>\n",
	$_[0] ? $_[0]->{'value'} : $_[1] ? $_[1]->{'value'} : '';
$rv .= sprintf "<input type=checkbox name=VirtualDocumentRoot_ip value=1 %s> %s\n",
	$_[1] ? 'checked' : '', $text{'mod_vhost_alias_ip'};

return (2, "$text{'mod_vhost_alias_root'}", $rv);
}

sub save_VirtualDocumentRoot_VirtualDocumentRootIP
{
if ($in{'VirtualDocumentRoot_def'}) {
	return ( [ ], [ ] );
	}
$in{'VirtualDocumentRoot'} =~ /^\S+$/ || &error($text{'mod_vhost_alias_eroot'});
&allowed_doc_dir($in{'VirtualDocumentRoot'}) ||
	&error($text{'mod_vhost_alias_eroot2'});
if ($in{'VirtualDocumentRoot_ip'}) {
	return ( [ ], [ $in{'VirtualDocumentRoot'} ] );
	}
else {
	return ( [ $in{'VirtualDocumentRoot'} ], [ ] );
	}
}

sub edit_VirtualScriptAlias_VirtualScriptAliasIP
{
$rv = sprintf "<input type=radio name=VirtualScriptAlias_def value=1 %s> %s\n",
	$_[0] || $_[1] ? '' : 'checked', $text{'mod_vhost_alias_none'};
$rv .= sprintf "<input type=radio name=VirtualScriptAlias_def value=0 %s>\n",
	$_[0] || $_[1] ? 'checked' : '';
$rv .= sprintf "<input name=VirtualScriptAlias size=50 value='%s'><br>\n",
	$_[0] ? $_[0]->{'value'} : $_[1] ? $_[1]->{'value'} : '';
$rv .= sprintf "<input type=checkbox name=VirtualScriptAlias_ip value=1 %s> %s\n",
	$_[1] ? 'checked' : '', $text{'mod_vhost_alias_ip'};

return (2, "$text{'mod_vhost_alias_script'}", $rv);
}

sub save_VirtualScriptAlias_VirtualScriptAliasIP
{
if ($in{'VirtualScriptAlias_def'}) {
	return ( [ ], [ ] );
	}
$in{'VirtualScriptAlias'} =~/^\S+$/ || &error($text{'mod_vhost_alias_escript'});
if ($in{'VirtualScriptAlias_ip'}) {
	return ( [ ], [ $in{'VirtualScriptAlias'} ] );
	}
else {
	return ( [ $in{'VirtualScriptAlias'} ], [ ] );
	}
}

