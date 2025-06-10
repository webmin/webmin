#  browsermatch.pl
# Functions used in mod_browser.pl and mod_setenvif.pl

sub edit_BrowserMatch_BrowserMatchNoCase
{
local($d, @w, $i, @regex, @var, @val, @case, $rv);
foreach $d (@{$_[0]}, @{$_[1]}) {
	@w = @{$d->{'words'}};
	for($i=1; $i<@w; $i++) {
		push(@regex, $w[0]);
		if ($w[$i] =~ /^\!(\S+)$/) { push(@var, $1); push(@val, undef); }
		elsif ($w[$i] =~ /^(\S+)=(\S*)$/) { push(@var, $1); push(@val, $2); }
		else { push(@var, $w[$i]); push(@val, 1); }
		if ($d->{'name'} eq "BrowserMatch") { push(@case, 1); }
		else { push(@case, 0); }
		}
	}
push(@regex, ""); push(@var, ""); push(@val, ""); push(@case, 0);
$rv = "<table border>\n".
      "<tr $tb> <td><b>$text{'browsermatch_regexp'}</b></td> <td><b>$text{'browsermatch_case'}</b></td>\n".
      "<td><b>$text{'browsermatch_var'}</b></td> <td><b>$text{'browsermatch_value'}</b></td> </tr>\n";
for($i=0; $i<@regex; $i++) {
	$rv .= "<tr $cb>\n";
	$rv .= sprintf
	        "<td><input size=20 name=Browser_regex_$i value=\"%s\"></td>\n",
	        $regex[$i];
	$rv .= "<td>".&choice_input($case[$i], "Browser_case_$i", 1,
	       "$text{'yes'},1", "$text{'no'},0")."</td>\n";
	$rv .= sprintf
	        "<td><input size=20 name=Browser_var_$i value=\"%s\"></td>\n",
	        $var[$i];
	$rv .= "<td>".&opt_input($val[$i], "Browser_val_$i",
				 "$text{'browsermatch_clear'}", 10)."</td>\n";
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return (2, "$text{'browsermatch_txt'}", $rv);
}
sub save_BrowserMatch_BrowserMatchNoCase
{
local($i, $regex, $case, $var, $val, $set, $lastbm, $lastbmnc, @bm, @bmnc);
for($i=0; defined($regex = $in{"Browser_regex_$i"}); $i++) {
	$case = $in{"Browser_case_$i"}; $var = $in{"Browser_var_$i"};
	if ($regex !~ /\S/ && $var !~ /\S/) { next; }
	$var =~ /^\S+$/ || &error(&text('browsermatch_evar', $var));
	$val = $in{"Browser_val_$i"};
	$set = $in{"Browser_val_${i}_def"} ? "!$var" :
		$val eq "1" ? $var : "$var=$val";
	if ($case) {
		if ($regex eq $lastbm) { $bm[$#bm] .= " $set"; }
		else { push(@bm, "\"$regex\" $set"); }
		$lastbm = $regex;
		}
	else {
		if ($regex eq $lastbmnc) { $bmnc[$#bmnc] .= " $set"; }
		else { push(@bmnc, "\"$regex\" $set"); }
		$lastbmnc = $regex;
		}
	}
return ( \@bm, \@bmnc );
}

1;

