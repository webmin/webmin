# mod_ext_filter.pl
# Module for defining filters that are external commands

sub mod_ext_filter_directives
{
local $rv;
$rv = [ [ 'ExtFilterDefine', 1, 18, 'global', 2.0 ] ];
return &make_directives($rv, $_[0], "mod_ext_filter");
}

sub mod_ext_filter_filters
{
local($d, @rv);
foreach $d (&find_all_directives($_[0], "ExtFilterDefine")) {
	push(@rv, $d->{'words'}->[0]);
	}
return @rv;
}

sub edit_ExtFilterDefine
{
local ($inrv, $outrv);
$outrv = $inrv = "<table border>\n".
	"<tr $tb> <td><b>$text{'filter_name'}</b></td>\n".
	"<td><b>$text{'filter_cmd'}</b></td>\n".
	"<td><b>$text{'filter_intype'}</b></td>\n".
	"<td><b>$text{'filter_outtype'}</b></td>\n".
	"<td><b>$text{'filter_preserve'}</b></td> </tr>\n";
local ($e, $i = 0);
foreach $e (@{$_[0]}, { 'value' => 'mode=output' },
		      { 'value' => 'mode=input' }) {
	local (%p, $str = $e->{'value'});
	while($str =~ /^\s*([^=\s]+)="([^"]*)"(.*)$/ ||
	      $str =~ /^\s*([^=\s]+)=([^=\s]+)(.*)$/ ||
	      $str =~ /^\s*([^=\s]+)()(.*)$/) {
		$p{lc($1)} = $2;
		$str = $3;
		}
	local $l = "<tr $cb>\n";
	local $m = $p{'mode'} ? $p{'mode'} : "output";
	$l .= "<input name=ExtFilterDefine_m_$i type=hidden value='$m'>\n";
	$l .= "<td><input name=ExtFilterDefine_n_$i size=10 value='$e->{'words'}->[0]'></td>\n";
	$l .= "<td><input name=ExtFilterDefine_c_$i size=30 value='$p{'cmd'}'></td>\n";
	$l .= "<td><input name=ExtFilterDefine_i_$i size=12 value='$p{'intype'}'></td>\n";
	$l .= "<td><input name=ExtFilterDefine_o_$i size=12 value='$p{'outtype'}'></td>\n";
	$l .= "<td><input type=checkbox name=ExtFilterDefine_p_$i value=1 ".
		(defined($p{'preservescontentlength'}) ? "checked" : "").
		"> $text{'yes'}</td>\n";
	$l .= "</tr>\n";
	if ($p{'mode'} eq 'input') { $inrv .= $l; }
	else { $outrv .= $l; }
	$i++;
	}
$inrv .= "</table>\n";
$outrv .= "</table>\n";
return (3, undef, "<b>$text{'filter_in'}</b><br>".$inrv."<p>\n".
		  "<b>$text{'filter_out'}</b><br>".$outrv);
}
sub save_ExtFilterDefine
{
local (@rv, $i);
for($i=0; defined($in{"ExtFilterDefine_n_$i"}); $i++) {
	next if (!$in{"ExtFilterDefine_n_$i"});
	$in{"ExtFilterDefine_n_$i"} =~ /^\S+$/ ||
		&error(&text('filter_ename', $in{"ExtFilterDefine_n_$i"}));
	$in{"ExtFilterDefine_c_$i"} ||
		&error(&text('filter_ecmd', $in{"ExtFilterDefine_n_$i"}));
	local $l = $in{"ExtFilterDefine_n_$i"}." mode=".
		   $in{"ExtFilterDefine_m_$i"}." cmd=\"".
		   $in{"ExtFilterDefine_c_$i"}."\"";
	if ($in{"ExtFilterDefine_i_$i"}) {
		$l .= " intype=".$in{"ExtFilterDefine_i_$i"};
		}
	if ($in{"ExtFilterDefine_o_$i"}) {
		$l .= " outtype=".$in{"ExtFilterDefine_o_$i"};
		}
	if ($in{"ExtFilterDefine_p_$i"}) {
		$l .= " PreservesContentLength";
		}
	push(@rv, $l);
	}
return ( \@rv );
}

