# mod_actions.pl
# Defines editors for CGI actions

sub mod_actions_directives
{
$rv = [ [ 'Action', 1, 11, 'virtual directory htaccess', undef, 5 ],
        [ 'Script', 1, 11, 'virtual directory' ] ];
return &make_directives($rv, $_[0], "mod_actions");
}

sub mod_actions_handlers
{
local($d, @rv);
foreach $d (&find_all_directives($_[0], "Action")) {
	if ($d->{'words'}->[0] =~ /^[A-z0-9\-\_]+$/) {
		push(@rv, $d->{'words'}->[0]);
		}
	}
return @rv;
}

sub edit_Action
{
local($rv, $len, $i, $type, $cgi);
$rv = "<table border>\n".
      "<tr $tb> <td><b>$text{'mod_actions_mime'}</b></td> <td><b>$text{'mod_actions_cgiurl'}</b></td> </tr>";
$len = @{$_[0]}+1;
for($i=0; $i<$len; $i++) {
	if ($_[0]->[$i]->{'value'} =~ /^(\S+)\s+(\S+)$/) {
		$type = $1; $cgi = $2;
		}
	else { $type = $cgi = ""; }
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input name=Action_type_$i size=20 value=\"$type\"></td>\n";
	$rv .= "<td><input name=Action_cgi_$i size=40 value=\"$cgi\"></td>\n";
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return (2, "$text{'mod_actions_mimecgi'}", $rv);
}
sub save_Action
{
local($i, $cgi, $type, @rv);
for($i=0; defined($in{"Action_type_$i"}); $i++) {
	$type = $in{"Action_type_$i"}; $cgi = $in{"Action_cgi_$i"};
	if ($type !~ /\S/ && $cgi !~ /\S/) { next; }
	$type =~ /^(\S+)$/ || &error(&text('mod_actions_emime', $type));
	$cgi =~ /^\/(\S+)$/ || &error(&text('mod_actions_ecgi', $cgi));
	push(@rv, "$type $cgi");
	}
return ( \@rv );
}

sub edit_Script
{
local($rv, $len, $i, $meth, $cgi, $m, $found);
$rv = "<table border>\n".
      "<tr $tb> <td><b>$text{'mod_actions_http'}</b></td> <td><b>$text{'mod_actions_cgi'}</b></td> </tr>";
$len = @{$_[0]}+1;
for($i=0; $i<$len; $i++) {
	if ($_[0]->[$i]->{'value'} =~ /^(\S+)\s+(\S+)$/) {
		$meth = $1; $cgi = $2;
		}
	else { $meth = $cgi = ""; }
	$rv .= "<tr $cb><td><select name=Script_meth_$i>\n";
	foreach $m ("", "GET", "POST", "PUT", "DELETE") {
		$rv .= sprintf "<option %s>$m</option>\n", $meth eq $m ? "selected" : "";
		$found++ if ($meth eq $m);
		}
	printf "<option selected>$meth</option>\n" if (!$found);
	$rv .= "</select></td>\n";
	$rv .= "<td><input name=Script_cgi_$i size=40 value=\"$cgi\"></td>\n";
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return (2, "$text{'mod_actions_httpcgi'}", $rv);
}
sub save_Script
{
local($i, @rv, $meth, $cgi);
for($i=0; defined($in{"Script_meth_$i"}); $i++) {
	$meth = $in{"Script_meth_$i"}; $cgi = $in{"Script_cgi_$i"};
	if (!$meth && $cgi !~ /\S/) { next; }
	$meth || &error(&text('mod_actions_enometh', $cgi));
	$cgi =~ /^\/(\S+)$/ || &error(&text('mod_actions_ecgi', $cgi));
	push(@rv, "$meth $cgi");
	}
return ( \@rv );
}

1;

