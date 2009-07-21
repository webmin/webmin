# mod_env.pl
# Defines editors for passing variables to CGI scripts

sub mod_env_directives
{
local($rv);
$rv = [ [ 'PassEnv UnsetEnv SetEnv', 1, 11, 'virtual', -1.309 ],
	[ 'PassEnv UnsetEnv SetEnv', 1, 11, 'virtual directory', 1.309 ] ];
return &make_directives($rv, $_[0], "mod_env");
}

sub edit_PassEnv_UnsetEnv_SetEnv
{
local($d, $e, @var, @mode, @val, $i, $rv);
foreach $d (@{$_[0]}, @{$_[1]}, @{$_[2]}) {
	if ($d->{'name'} ne "SetEnv") {
		foreach $e (@{$d->{'words'}}) {
			push(@var, $e);
			push(@mode, $d->{'name'} eq "PassEnv" ? 0 : 1);
			push(@val, "");
			}
		}
	else {
		push(@var, $d->{'words'}->[0]);
		push(@mode, 2);
		push(@val, $d->{'words'}->[1]);
		}
	}
push(@var, ""); push(@mode, 0); push(@val, "");
$rv = "<table border>\n".
      "<tr $tb> <td><b>$text{'mod_env_var'}</b></td> <td><b>$text{'mod_env_value'}</b></td> </tr>\n";
for($i=0; $i<@var; $i++) {
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input name=Env_var_$i size=20 value=\"$var[$i]\"></td>\n";
	$rv .= "<td>".&choice_input($mode[$i], "Env_mode_$i", 0,
	                            "$text{'mod_env_pass'},0", "$text{'mod_env_clear'},1", "$text{'mod_env_set'},2");
	$rv .= "<input name=Env_val_$i size=20 value=\"$val[$i]\"></td>\n";
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return (2, "$text{'mod_env_cgivar'}", $rv);
}
sub save_PassEnv_UnsetEnv_SetEnv
{
local($i, $var, $mode, $val, @pa, @uns, @se);
for($i=0; defined($var = $in{"Env_var_$i"}); $i++) {
	$mode = $in{"Env_mode_$i"}; $val = $in{"Env_val_$i"};
	if ($var !~ /\S/ && $val !~ /\S/) { next; }
	$var =~ /^\S+$/ || &error(&text('mod_env_evar', $var));
	if ($mode == 0) { push(@pa, $var); }
	elsif ($mode == 1) { push(@uns, $var); }
	elsif ($var !~ /^\S+$/) {
		&error(&text('mod_env_evalue', $var));
		}
	else { push(@se, "$var \"$val\""); }
	}
return ( \@pa, \@uns, \@se );
}

sub edit_PassEnvAll
{
return (1, "$text{'mod_env_passall'}",
	&choice_input($_[0]->{'value'}, "PassEnvAll",
		      "", "$text{'yes'},on", "$text{'no'},off", "$text{'mod_env_default'},"));
}
sub save_PassEnvAll
{
return &parse_choice("PassEnvAll");
}

1;

