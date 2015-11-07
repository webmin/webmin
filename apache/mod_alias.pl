# mod_alias.pl
# Defines editors for alias module directives

sub mod_alias_directives
{
$rv = [ [ 'Alias', 1, 10, 'virtual' ],
	[ 'AliasMatch', 1, 10, 'virtual', 1.3 ],
	[ 'Redirect', 1, 10, 'virtual directory htaccess', 1.2 ],
	[ 'Redirect', 1, 10, 'virtual', '-1.2' ],
	[ 'RedirectMatch', 1, 10, 'virtual', 1.3 ],
	[ 'RedirectTemp', 1, 10, 'virtual directory htaccess', 1.2 ],
	[ 'RedirectPermanent', 1, 10, 'virtual directory htaccess', 1.2 ],
	[ 'ScriptAlias', 1, 11, 'virtual', undef, 10 ],
	[ 'ScriptAliasMatch', 1, 11, 'virtual', 1.3, 10 ] ];
return &make_directives($rv, $_[0], "mod_alias");
}

# alias_input(array, name, title)
sub alias_input
{
local($rv, $len, $i, $from, $to);
$rv = "<table border>\n".
      "<tr $tb> <td><b>$text{'mod_alias_from'}</b></td> <td><b>$text{'mod_alias_to'}</b></td> </tr>\n";
$len = @{$_[0]} + 1;
for($i=0; $i<$len; $i++) {
	$from = $_[0]->[$i]->{'words'}->[0];
	$to = $_[0]->[$i]->{'words'}->[1];
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input name=$_[1]_from_$i size=20 value=\"$from\"></td>\n";
	$rv .= "<td><input name=$_[1]_to_$i size=40 value=\"$to\"></td>\n";
	$rv .= "</tr>\n";
	$rv .= &ui_hidden("$_[1]_old_to_$i", $to);
	}
$rv .= "</table>\n";
return (2, $_[2], $rv);
}

%alias_statmap = ("permanent", 301,  "temp", 302,
		  "seeother", 303,   "gone", 410);
$url_regexp = '^(http:\/\/|ftp:\/\/|gopher:|https:\/\/|mailto:|telnet:|\/)(\S+)$';

# alias_status_input(array, name, title)
sub alias_status_input
{
local($rv, $len, $i, $from, $to, $stat);
$rv = "<table border>\n".
      "<tr $tb> <td><b>$text{'mod_alias_from'}</b></td> <td><b>$text{'mod_alias_status'}</b></td> <td><b>$text{'mod_alias_to'}</b></td> </tr>\n";
$len = @{$_[0]} + 1;
for($i=0; $i<$len; $i++) {
	if ($_[0]->[$i]->{'words'}->[0] =~ /^(permanent|temp|seeother|gone|\d+)$/) {
		$stat = $_[0]->[$i]->{'words'}->[0];
		$from = $_[0]->[$i]->{'words'}->[1];
		$to = $_[0]->[$i]->{'words'}->[2];
		if ($alias_statmap{$stat}) { $stat = $alias_statmap{$stat}; }
		}
	else {
		$stat = "";
		$from = $_[0]->[$i]->{'words'}->[0];
		$to = $_[0]->[$i]->{'words'}->[1];
		}
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input name=$_[1]_from_$i size=20 value=\"$from\"></td>\n";
	$rv .= "<td><input name=$_[1]_stat_$i size=4 value=\"$stat\"></td>\n";
	$rv .= "<td><input name=$_[1]_to_$i size=40 value=\"$to\"></td>\n";
	$rv .= "</tr>\n";
	$rv .= &ui_hidden("$_[1]_old_to_$i", $to);
	}
$rv .= "</table>\n";
return (2, $_[2], $rv);
}

# parse_alias(name, title, regexp)
sub parse_alias
{
local($re, @rv, $i, $from, $to);
$re = $_[2];
for($i=0; defined($in{"$_[0]_from_$i"}); $i++) {
	$from = $in{"$_[0]_from_$i"};
	$to = $in{"$_[0]_to_$i"};
	$old_to = $in{"$_[0]_old_to_$i"};
	if ($from !~ /\S/ && $to !~ /\S/) { next; }
	if ($from !~ /^\S+$/) { &error(&text('mod_alias_efrom', $from, $_[1])); }
	if ($to !~ /$re/) { &error(&text('mod_alias_edest', $to, $_[1])); }
	&allowed_doc_dir($to) ||
	    $old_to && !&allowed_doc_dir($old_to) ||
		&error(&text('mod_alias_edest2', $to, $_[1]));
	if ($to =~ /^[a-zA-Z0-9:\/\.\-]+$/) {
		push(@rv, "$from $to");
		}
	else {
		push(@rv, "$from \"$to\"");
		}
	}
return ( \@rv );
}

# parse_alias_status(name, title, regexp)
sub parse_alias_status
{
local($re, @rv, $i, $from, $to, $stat);
$re = $_[2];
for($i=0; defined($in{"$_[0]_from_$i"}); $i++) {
	$from = $in{"$_[0]_from_$i"};
	$to = $in{"$_[0]_to_$i"};
	$old_to = $in{"$_[0]_old_to_$i"};
	$stat = $in{"$_[0]_stat_$i"};
	if ($from !~ /\S/ && $to !~ /\S/) { next; }
	if ($from !~ /^\S+$/) { &error(&text('mod_alias_efrom', $from, $_[1])); }
	if ($stat !~ /^(\d*)$/) { &error(&text('mod_alias_estatus', $stat)); }
	if (!$stat || $stat >= 300 && $stat <= 399) {
		if ($to !~ /$re/) {
			&error(&text('mod_alias_edest', $to, $_[1]));
			}
		&allowed_doc_dir($to) ||
	            $old_to && !&allowed_doc_dir($old_to) ||
			&error(&text('mod_alias_edest2', $to, $_[1]));
		}
	else { $to = ""; }
	$to = "\"$to\"" if ($to);
	if ($stat) { push(@rv, "$stat $from $to"); }
	else { push(@rv, "$from $to"); }
	}
return ( \@rv );
}

sub edit_Alias
{
return &alias_input($_[0], "Alias", $text{'mod_alias_alias'});
}
sub save_Alias
{
return &parse_alias("Alias", $text{'mod_alias_alias2'}, '\S');
}

sub edit_AliasMatch
{
return &alias_input($_[0], "AliasMatch", $text{'mod_alias_regexp'});
}
sub save_AliasMatch
{
return &parse_alias("AliasMatch", $text{'mod_alias_regexp2'}, '\S');
}

sub edit_Redirect
{
if ($_[1]->{'version'} >= 1.2) {
	return &alias_status_input($_[0], "Redirect", $text{'mod_alias_redir'});
	}
else { return &alias_input($_[0], "Redirect", $text{'mod_alias_redir'}); }
}
sub save_Redirect
{
if ($_[0]->{'version'} >= 1.2) {
	return &parse_alias_status("Redirect", $text{'mod_alias_redir2'}, $url_regexp);
	}
else { return &parse_alias("Redirect", $text{'mod_alias_redir2'}, $url_regexp); }
}

sub edit_RedirectMatch
{
return &alias_status_input($_[0], "RedirectMatch", $text{'mod_alias_rredir'});
}
sub save_RedirectMatch
{
return &parse_alias_status("RedirectMatch", $text{'mod_alias_rredir2'}, $url_regexp);
}

sub edit_RedirectTemp
{
return &alias_input($_[0], "RedirectTemp", $text{'mod_alias_tredir'});
}
sub save_RedirectTemp
{
return &parse_alias("RedirectTemp", $text{'mod_alias_tredir2'}, $url_regexp);
}

sub edit_RedirectPermanent
{
return &alias_input($_[0], "RedirectPermanent", $text{'mod_alias_predir'});
}
sub save_RedirectPermanent
{
return &parse_alias("RedirectPermanent", $text{'mod_alias_predir2'}, $url_regexp);
}

sub edit_ScriptAlias
{
return &alias_input($_[0], "ScriptAlias", $text{'mod_alias_cgi'});
}
sub save_ScriptAlias
{
return &parse_alias("ScriptAlias", $text{'mod_alias_cgi2'}, '^\S+$');
}

sub edit_ScriptAliasMatch
{
return &alias_input($_[0], "ScriptAliasMatch", $text{'mod_alias_rcgi'});
}
sub save_ScriptAliasMatch
{
return &parse_alias("ScriptAliasMatch", $text{'mod_alias_rcgi2'}, '^\S+$');
}

1;
