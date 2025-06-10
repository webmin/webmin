# mod_log_agent.pl
# Defines editors for logging user agents

sub mod_log_agent_directives
{
$rv = [ [ 'AgentLog', 0, 3, 'virtual' ] ];
return &make_directives($rv, $_[0], "mod_log_agent");
}

sub edit_AgentLog
{
local($rv);
$rv = sprintf "<input type=radio name=AgentLog_mode value=0 %s> $text{'mod_log_agent_default'}\n",
       $_[0] ? "" : "checked";
$rv .= sprintf "<input type=radio name=AgentLog_mode value=1 %s> $text{'mod_log_agent_file'}",
	 $_[0] && $_[0]->{'value'} !~ /^\|/ ? "checked" : "";
$rv .= sprintf "<input type=radio name=AgentLog_mode value=2 %s> $text{'mod_log_agent_program'}",
	 $_[0]->{'value'} =~ /^\|/ ? "checked" : "";
$rv .= sprintf "<input name=AgentLog size=20 value=\"%s\">\n",
        $_[0]->{'value'} =~ /^\|(.*)$/ ? $1 : $_[0]->{'value'};
return (1, "$text{'mod_log_agent_log'}", $rv); 
}
sub save_AgentLog
{
if ($in{'AgentLog_mode'} == 0) { return ( [ ] ); }
$in{'AgentLog'} =~ /^\S+$/ ||
	&error(&text('mod_log_agent_efile', $in{'AgentLog'}));
if ($in{'AgentLog_mode'} == 1) { return ( [ $in{'AgentLog'} ] ); }
else { return ( [ "|$in{'AgentLog'}" ] ); }
}

1;

