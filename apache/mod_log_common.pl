# mod_log_common.pl
# Defines editors for logging

sub mod_log_common_directives
{
$rv = [ [ 'TransferLog', 0, 3, 'virtual', -1.2 ] ];
return &make_directives($rv, $_[0], "mod_log_common");
}

sub edit_TransferLog
{
local($rv);
$rv = sprintf "<input type=radio name=TransferLog_mode value=0 %s> Default\n",
       $_[0] ? "" : "checked";
$rv .= sprintf "<input type=radio name=TransferLog_mode value=1 %s> File..",
	 $_[0] && $_[0]->{'value'} !~ /^\|/ ? "checked" : "";
$rv .= sprintf "<input type=radio name=TransferLog_mode value=2 %s> Program..",
	 $_[0]->{'value'} =~ /^\|/ ? "checked" : "";
$rv .= sprintf "<input name=TransferLog size=20 value=\"%s\">\n",
        $_[0]->{'value'} =~ /^\|(.*)$/ ? $1 : $_[0]->{'value'};
return (1, "Access log file", $rv); 
}
sub save_TransferLog
{
if ($in{'TransferLog_mode'} == 0) { return ( [ ] ); }
$in{'TransferLog'} =~ /^\S+$/ ||
	&error("$in{'TransferLog'} is not a valid access log filename");
&allowed_auth_file($in{'TransferLog'}) ||
	&error("access log is not under the allowed directory");
if ($in{'TransferLog_mode'} == 1) { return ( [ $in{'TransferLog'} ] ); }
else { return ( [ "|$in{'TransferLog'}" ] ); }
}

1;

