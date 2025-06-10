# mod_log_referer.pl
# Defines editors for logging

sub mod_log_referer_directives
{
$rv = [ [ 'RefererLog', 0, 3, 'virtual' ],
        [ 'RefererIgnore', 0, 3, 'virtual' ] ];
return &make_directives($rv, $_[0], "mod_log_referer");
}

sub edit_RefererLog
{
local($rv);
$rv = sprintf "<input type=radio name=RefererLog_mode value=0 %s> $text{'mod_log_referer_default'}\n",
       $_[0] ? "" : "checked";
$rv .= sprintf "<input type=radio name=RefererLog_mode value=1 %s> $text{'mod_log_referer_file'}",
	 $_[0] && $_[0]->{'value'} !~ /^\|/ ? "checked" : "";
$rv .= sprintf "<input type=radio name=RefererLog_mode value=2 %s> $text{'mod_log_referer_program'}",
	 $_[0]->{'value'} =~ /^\|/ ? "checked" : "";
$rv .= sprintf "<input name=RefererLog size=20 value=\"%s\">\n",
        $_[0]->{'value'} =~ /^\|(.*)$/ ? $1 : $_[0]->{'value'};
return (1, "$text{'mod_log_referer_log'}", $rv); 
}
sub save_RefererLog
{
if ($in{'RefererLog_mode'} == 0) { return ( [ ] ); }
$in{'RefererLog'} =~ /^\S+$/ ||
	&error(&text('mod_log_referer_elog', $in{'RefererLog'}));
&allowed_auth_file($in{'RefererLog'}) ||
	&error($text{'mod_log_referer_edir'});
if ($in{'RefererLog_mode'} == 1) { return ( [ $in{'RefererLog'} ] ); }
else { return ( [ "|$in{'RefererLog'}" ] ); }
}

sub edit_RefererIgnore
{
local($rv);
$rv = "<textarea name=RefererIgnore rows=3 cols=20>".
      join("\n", split(/\s+/, $_[0]->{'value'})).
      "</textarea>\n";
return (1, "$text{'mod_log_referer_nolog'}", $rv);
}
sub save_RefererIgnore
{
local(@rv);
@rv = split(/\s+/, $in{'RefererIgnore'});
if (@rv) { return ( [ join(' ', @rv) ] ); }
else { return ( [ ] ); }
}

1;

