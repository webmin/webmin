# mod_access.pl
# Defines editors for host restriction directives

sub mod_access_directives
{
local($rv);
$rv = [ [ 'allow deny order', 1, 4, 'directory htaccess' ] ];
return &make_directives($rv, $_[0], "mod_access");
}

sub edit_allow_deny_order
{
local($d, @w, $i, @type, @mode, @what, $rv);
foreach $d (@{$_[0]}, @{$_[1]}) {
	@w = split(/\s+/, $d->{'value'});
	for($i=1; $i<@w; $i++) {
		push(@type, lc($d->{'name'}) eq "allow" ? 1 : 2);
		push(@what, $w[$i]);
		if ($w[$i] =~ /^env=(\S+)$/) {
			$what[$#what] = $1;
			push(@mode, 6);
			}
		elsif ($w[$i] =~ /^[0-9\.]+\/[0-9]+$/) { push(@mode, 5); }
		elsif ($w[$i] =~ /^[0-9\.]+\/[0-9\.]+$/) { push(@mode, 4); }
		elsif ($w[$i] =~ /^\d+\.\d+\.\d+\.\d+$/) { push(@mode, 2); }
		elsif ($w[$i] =~ /^[0-9\.]+$/) { push(@mode, 3); }
		elsif ($w[$i] eq "all") { push(@mode, 0); }
		else { push(@mode, 1); }
		}
	}
push(@type, ""); push(@what, ""); push(@mode, 0);
$rv = "<i>$text{'mod_access_order'}</i>\n".
      &choice_input($_[2]->[0]->{'value'}, "order", "",
       "$text{'mod_access_denyallow'},deny,allow", "$text{'mod_access_allowdeny'},allow,deny",
       "$text{'mod_access_mutual'},mutual-failure", "$text{'mod_access_default'},")."<br>\n";
$rv .= "<table border>\n".
       "<tr $tb> <td><b>$text{'mod_access_action'}</b></td> <td><b>$text{'mod_access_cond'}</b></td> </tr>\n";
@sels = ("$text{'mod_access_all'},0", "$text{'mod_access_host'},1",
	 "$text{'mod_access_ip'},2", "$text{'mod_access_pip'},3");
if ($_[3]->{'version'} >= 1.3) {
	push(@sels, "$text{'mod_access_mask'},4",
		    "$text{'mod_access_cidr'},5");
	}
if ($_[3]->{'version'} >= 1.2) {
	push(@sels, "$text{'mod_access_var'},6");
	}
for($i=0; $i<@type; $i++) {
	$rv .= "<tr $cb> <td>".&select_input($type[$i], "allow_type_$i", "",
	       ",0", "$text{'mod_access_allow'},1", "$text{'mod_access_deny'},2")."</td>\n";
	$rv .= "<td>".&select_input($mode[$i], "allow_mode_$i", "0", @sels);
	$rv .= sprintf "<input name=allow_what_$i size=20 value=\"%s\"></td>\n",
	        $mode[$i] ? $what[$i] : "";
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return (2, "$text{'mod_access_restr'}", $rv);
}
sub save_allow_deny_order
{
local($i, $type, $mode, $what, @allow, @deny);
for($i=0; defined($type = $in{"allow_type_$i"}); $i++) {
	$mode = $in{"allow_mode_$i"}; $what = $in{"allow_what_$i"};
	if (!$type) { next; }
	if ($mode == 0) { $what = "all"; }
	elsif ($mode == 2 && !&check_ipaddress($what) &&
			     !&check_ip6address($what)) {
		&error(&text('mod_access_eip', $what));
		}
	elsif ($mode == 3 && $what !~ /^[0-9\.]+$/) {
		&error(&text('mod_access_epip', $what));
		}
	elsif ($mode == 4 && ($what !~ /^([0-9\.:]+)\/([0-9\.:]+)$/ ||
	       (!&check_ipaddress($1) && !&check_ip6address($1)) ||
	       (!&check_ipaddress($2) && !&check_ip6address($2)))) {
		&error(&text('mod_access_emask', $what));
		}
	elsif ($mode == 5 && ($what !~ /^([0-9\.:]+)\/([0-9]+)$/ ||
	       !&check_ipaddress($1) || $2 > 32)) {
		&error(&text('mod_access_ecidr', $what));
		}
	elsif ($mode == 6) {
		$what =~ /^\S+$/ ||
			&error(&text('mod_access_evar', $what));
		$what = "env=$what";
		}
	if ($type == 1) { push(@allow, "from $what"); }
	else { push(@deny, "from $what"); }
	}
return ( \@allow, \@deny, &parse_choice("order", ""));
}

1;

