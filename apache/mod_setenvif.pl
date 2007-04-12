# mod_setenvif.pl
# Defines editors for directives to set environment variables

sub mod_setenvif_directives
{
local($rv);
$rv = [ [ 'BrowserMatch BrowserMatchNoCase', 1, 11, 'global', '-1.313' ],
	[ 'BrowserMatch BrowserMatchNoCase', 1, 11, 'virtual directory htaccess', 1.313 ],
        [ 'SetEnvIf SetEnvIfNoCase', 1, 11, 'global', '1.3-1.313' ],
        [ 'SetEnvIf SetEnvIfNoCase', 1, 11, 'virtual directory htaccess', 1.313 ] ];
return &make_directives($rv, $_[0], "mod_setenvif");
}

require 'browsermatch.pl';

sub edit_SetEnvIf_SetEnvIfNoCase
{
local($d, @w, $i, @head, @regex, @var, @val, @case, $rv);
foreach $d (@{$_[0]}, @{$_[1]}) {
	@w = @{$d->{'words'}};
	for($i=2; $i<@w; $i++) {
		push(@head, $w[0]);
		push(@regex, $w[1]);
		if ($w[$i] =~ /^\!(\S+)$/)
			{ push(@var, $1); push(@val, undef); }
		elsif ($w[$i] =~ /^(\S+)=(\S*)$/)
			{ push(@var, $1); push(@val, $2); }
		else { push(@var, $w[$i]); push(@val, 1); }
		if ($d->{'name'} eq "SetEnvIf") { push(@case, 1); }
		else { push(@case, 0); }
		}
	}
push(@head, ""); push(@regex, ""); push(@var, ""); push(@val, ""); push(@case, 0);
$rv = "<table border>\n".
      "<tr $tb> <td><b>$text{'mod_setenvif_header'}</b></td> <td><b>$text{'mod_setenvif_match'}</b></td>\n".
      "<td><b>$text{'mod_setenvif_case'}</b></td> <td><b>$text{'mod_setenvif_var'}</b></td>\n".
      "<td><b>$text{'mod_setenvif_value'}</b></td> </tr>\n";
for($i=0; $i<@head; $i++) {
	$rv .= "<tr $cb>\n";
	$rv .= sprintf
	        "<td><input size=15 name=SetEnvIf_head_$i value=\"%s\"></td>\n",
	        $head[$i];
	$rv .= sprintf
	        "<td><input size=10 name=SetEnvIf_regex_$i value=\"%s\"></td>\n",
	        $regex[$i];
	$rv .= "<td>".&choice_input($case[$i], "SetEnvIf_case_$i", 1,
	       "$text{'yes'},1", "$text{'no'},0")."</td>\n";
	$rv .= sprintf
	        "<td><input size=20 name=SetEnvIf_var_$i value=\"%s\"></td>\n",
	        $var[$i];
	$rv .= "<td>".&opt_input($val[$i], "SetEnvIf_val_$i",
	       "$text{'mod_setenvif_clear'}", 10)."</td>\n";
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return (2, "$text{'mod_setenvif_txt'}", $rv);
}
sub save_SetEnvIf_SetEnvIfNoCase
{
local($i, $head, $regex, $case, $var, $val,
      $set, $lastsi, $lastsnc, @si, @sinc);
for($i=0; defined($head = $in{"SetEnvIf_head_$i"}); $i++) {
	$regex = $in{"SetEnvIf_regex_$i"}; $case = $in{"SetEnvIf_case_$i"};
	$var = $in{"SetEnvIf_var_$i"};
	$val = $in{"SetEnvIf_val_${i}_def"} ? undef : $in{"SetEnvIf_val_$i"};
	if ($head !~ /\S/ && $regex !~ /\S/ && $var !~ /\S/) { next; }
	$head =~ /^\S+$/ || &error(&text('mod_setenvif_eheader', $head));
	$regex =~ /^\S+$/ || &error(&text('mod_setenvif_eregex', $regex));
	$var =~ /^\S+$/ || &error(&text('mod_setenvif_evar', $var));
	$set = !defined($val) ? "!$var" : $val eq "1" ? $var : "$var=$val";
	if ($case) {
		if ("$head $regex" eq $lastsi) { $si[$#si] .= " $set"; }
		else { push(@si, "$head $regex $set"); }
		$lastsi = "$head $regex";
		}
	else {
		if ("$head $regex" eq $lastsinc) { $sinc[$#sinc] .= " $set"; }
		else { push(@sinc, "$head $regex $set"); }
		$lastsinc = "$head $regex";
		}
	}
return ( \@si, \@sinc );
}

1;

