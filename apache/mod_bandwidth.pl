# mod_bandwidth.pl
# Editors for bandwidth-limiting directives

sub mod_bandwidth_directives
{
local $rv;
$rv = [ [ 'BandWidthDataDir', 0, 1, 'global', undef, -1 ],
	[ 'BandWidthModule', 0, 1, 'virtual' ],
	[ 'BandWidth', 1, 1, 'directory htaccess' ],
	[ 'LargeFileLimit', 1, 1, 'directory htaccess' ],
	[ 'MaxConnection', 0, 1, 'directory htaccess' ],
#	[ 'MinBandWidth', 1, 1, 'directory htaccess' ]
	[ 'BandWidthPulse', 0, 1, 'virtual' ]
      ];
return &make_directives($rv, $_[0], "mod_bandwidth");
}

sub edit_BandWidthDataDir
{
return (2,
	$text{'mod_band_dir'},
	&opt_input($_[0]->{'value'}, "BandWidthDataDir", $text{'default'}, 40));
}
sub save_BandWidthDataDir
{
if (!$in{'BandWidthDataDir_def'}) {
	-d $in{'BandWidthDataDir'} || &error($text{'mod_band_edir'});
	local $sd;
	foreach $sd ('master', 'link') {
		-d "$in{'BandWidthDataDir'}/$sd" ||
			&error(&text('mod_band_esubdir', $sd));
		}
	}
return &parse_opt("BandWidthDataDir");
}

sub edit_BandWidthModule
{
return (1, $text{'mod_band_enable'},
	&choice_input($_[0]->{'value'}, "BandWidthModule", "",
	      "$text{'yes'},on", "$text{'no'},off", "$text{'default'},"));
}
sub save_BandWidthModule
{
return &parse_choice("BandWidthModule");
}

sub edit_BandWidth
{
local ($rv, $i, $max);
$rv = "<table border>\n".
      "<tr $tb> <td><b>$text{'mod_band_bw'}</b></td>\n".
      "<td><b>$text{'mod_band_client'}</b></td> </tr>\n";
$max = @{$_[0]}+1;
for($i=0; $i<$max; $i++) {
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input name=BandWidth_bw_$i size=10 ".
	       "value=\"$_[0]->[$i]->{'words'}->[1]\"></td>\n";
	local $client = $_[0]->[$i]->{'words'}->[0];
	$rv .= sprintf
	        "<td><input type=radio name=BandWidth_all_$i value=1 %s> $text{'mod_band_all'}\n",
	        $client eq "all" ? "checked" : "";
	$rv .= sprintf
	        "<input type=radio name=BandWidth_all_$i value=0 %s> $text{'mod_band_ent'}\n",
	        $client eq "all" ? "" : "checked";
	$rv .= sprintf
	        "<input name=BandWidth_$i size=20 value=\"%s\"></td>\n",
	        $client eq "all" ? "" : $client;
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return (2, $text{'mod_band_bandwidth'}, $rv);
}
sub save_BandWidth
{
local ($i, $bw, $client, $all, @rv);
for($i=0; defined($bw = $in{"BandWidth_bw_$i"}); $i++) {
	$client = $in{"BandWidth_$i"};
	$all = $in{"BandWidth_all_$i"};
	next if ($bw eq "");
	$bw =~ /^\d+$/ || &error(&text('mod_band_ebw', $bw));
	$all || $client =~ /^[a-z0-9\.\-\_\/]+$/i ||
		&error(&text('mod_band_eclient', $bw));
	push(@rv, ($all ? "all" : $client)." ".$bw);
	}
return ( \@rv );
}

sub edit_LargeFileLimit
{
local ($rv, $i, $max);
$rv = "<table border>\n".
      "<tr $tb> <td><b>$text{'mod_band_bw'}</b></td>\n".
      "<td><b>$text{'mod_band_size'}</b></td> </tr>\n";
$max = @{$_[0]}+1;
for($i=0; $i<$max; $i++) {
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input name=LargeFileLimit_bw_$i size=10 ".
	       "value=\"$_[0]->[$i]->{'words'}->[1]\"></td>\n";
	$rv .= "<td><input name=LargeFileLimit_$i size=10 ".
	       "value=\"$_[0]->[$i]->{'words'}->[0]\"></td>\n";
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return (2, $text{'mod_band_sizelimit'}, $rv);
}
sub save_LargeFileLimit
{
local ($i, $bw, $size, @rv);
for($i=0; defined($bw = $in{"LargeFileLimit_bw_$i"}); $i++) {
	$size = $in{"LargeFileLimit_$i"};
	next if ($bw eq "");
	$bw =~ /^\d+$/ || &error(&text('mod_band_ebw', $bw));
	$size =~ /^\d+$/ || $size == -1 || &error(&text('mod_band_esize', $bw));
	push(@rv, "$size $bw");
	}
return ( \@rv );
}

sub edit_MaxConnection
{
return (1,
	$text{'mod_band_max'},
	&opt_input($_[0]->{'value'}, "MaxConnections", $text{'default'}, 4));
}
sub save_MaxConnection
{
return &parse_opt("MaxConnections", '^\d+$',
		  $text{'mod_band_emax'});
}

sub edit_BandWidthPulse
{
return (1,
	$text{'mod_band_pulse'},
	&opt_input($_[0]->{'value'}, "BandWidthPulse", $text{'default'}, 4));
}
sub save_BandWidthPulse
{
return &parse_opt("BandWidthPulse", '^\d+$',
		  $text{'mod_band_epulse'});
}

1;

