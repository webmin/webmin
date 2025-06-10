# mod_php4.pl
# PHP4 Directives
# By Sebastian Delmont <sdelmont@loquesea.com>

sub mod_php4_directives
{
$rv = [ [ 'php_value', 1, 16, 'virtual directory htaccess', undef, 10 ],
	[ 'php_flag', 1, 16, 'virtual directory htaccess', undef, 2 ],
	[ 'php_admin_value', 1, 16, 'virtual directory htaccess', undef, 10 ],
	[ 'php_admin_flag', 1, 16, 'virtual directory htaccess', undef, 2 ],
      ];
return &make_directives($rv, $_[0], "mod_php4");
}

sub mod_php4_handlers
{
return ("php4-script");
}

sub edit_php_value
{
return &php_value_form($_[0], "php_value");
}

sub edit_php_admin_value
{
return &php_value_form($_[0], "php_admin_value");
}

# php_value_form(&values, name)
sub php_value_form
{
local($rv, $name, $value, $len);
$rv = "";

$len = @{$_[0]} + 1;
for($i=0; $i<$len; $i++) {
	if ($_[0]->[$i]->{'value'} =~ /^(\S+)\s+(.+)$/) {
		$name = $1; $value = $2;
		}
	else { $name = $value = ""; }
	$rv .= "<input name=mod_$_[1]_name_$i size=20 value='$name'>&nbsp;";
	$rv .= "<input name=mod_$_[1]_value_$i size=30 value='$value'><BR>\n";
	}
return (2, "$text{'mod_'.$_[1]}", $rv);
}

sub save_php_value
{
return &php_value_save("php_value");
}

sub save_php_admin_value
{
return &php_value_save("php_admin_value");
}

# php_value_save(name)
sub php_value_save
{
local($i, $name, $value, @rv);
for($i=0; defined($in{"mod_$_[0]_name_$i"}); $i++) {
	$name = $in{"mod_$_[0]_name_$i"}; $value = $in{"mod_$_[0]_value_$i"};
	if ($name !~ /\S/ && $value !~ /\S/) { next; }
	$name =~ /^(\S+)$/ || &error(&text('mod_php_ename', $name));
	$value =~ /^(.+)$/ || &error(&text('mod_php_evalue', $name, $value));
	push(@rv, "$name $value");
	}
return ( \@rv );
}

sub edit_php_flag
{
return &php_flag_form($_[0], "php_flag");
}

sub edit_php_admin_flag
{
return &php_flag_form($_[0], "php_admin_flag");
}

# php_flag_form(&values, name)
sub php_flag_form
{
local($rv, $name, $value, $len);
$rv = "";

$len = @{$_[0]} + 1;
for($i=0; $i<$len; $i++) {
	if ($_[0]->[$i]->{'value'} =~ /^(\S+)\s+(on|off)$/) {
		$name = $1; $value = $2;
		}
	else { $name = $value = ""; }
	$rv .= "<input name=mod_$_[1]_name_$i size=20 value='$name'>&nbsp;";
	$rv .= "<input name=mod_$_[1]_value_$i type=radio value=on" . ($value eq "on" ? " checked" : "" ) . ">on&nbsp;";
	$rv .= "<input name=mod_$_[1]_value_$i type=radio value=off" . ($value eq "off" ? " checked" : "" ) . ">off&nbsp;<BR>";
	}
return (2, "$text{'mod_'.$_[1]}", $rv);
}

sub save_php_flag
{
return &php_flag_save("php_flag");
}

sub save_php_admin_flag
{
return &php_flag_save("php_admin_flag");
}

# php_flag_save(name)
sub php_flag_save
{
local($i, $name, $value, @rv);
for($i=0; defined($in{"mod_$_[0]_name_$i"}); $i++) {
	$name = $in{"mod_$_[0]_name_$i"}; $value = $in{"mod_$_[0]_value_$i"};
	if ($name !~ /\S/ ) { next; }
	$name =~ /^(\S+)$/ || &error(&text('mod_php_ename', $name));
	$value =~ /^(on|off)$/i || &error(&text('mod_php_evalue', $name, $value));
	push(@rv, "$name $value");
	}
return ( \@rv );
}

1;
