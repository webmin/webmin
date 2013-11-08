# redhat-driver.pl
# Functions for printer drivers as created by redhat

%paper_sizes = ( 'a4', 'A4',
		 'a3', 'A3',
		 'letter', 'US Letter',
		 'legal', 'Legal',
		 'ledger', 'Ledger' );
$rhs_drivers_file = "/usr/lib/rhs/rhs-printfilters/printerdb";
$base_driver = "/usr/lib/rhs/rhs-printfilters/master-filter";
$smb_driver = "/usr/lib/rhs/rhs-printfilters//smbprint";
$ncp_driver = "/usr/lib/rhs/rhs-printfilters//ncpprint";

# is_windows_driver(path, %driver)
# Returns a driver structure if some path is a windows driver
sub is_windows_driver
{
local $sd = "$config{'spool_dir'}/$_[1]->{'name'}";
if (($_[0] eq $smb_driver || $_[0] eq "$sd/filter") && -r "$sd/.config" &&
    $_[1]->{'comment'} =~ /^##PRINTTOOL3##\s+SMB/) {
	# Looks like a redhat SMB driver
	local %sconfig;
	&read_env_file("$sd/.config", \%sconfig);
	$sconfig{'share'} =~ /^\\\\(.*)\\(.*)$/;
	return { 'server' => $1,
		 'share' => $2,
		 'user' => $sconfig{'user'},
		 'pass' => $sconfig{'password'},
		 'workgroup' => $sconfig{'workgroup'},
		 'program' => $_[0] eq "$sd/filter" ? "$sd/filter" : undef };
	}
return undef;
}

# is_driver(path, &printer)
# Returns a structure containing the details of a driver
sub is_driver
{
if (!$_[0]) {
	return { 'mode' => 0,
		 'desc' => "$text{'redhat_none'}" };
	}
local $sd = "$config{'spool_dir'}/$_[1]->{'name'}";
if ($_[0] eq "$sd/filter" &&
    $_[1]->{'comment'} =~ /^##PRINTTOOL3##\s+(LOCAL|REMOTE|SMB)\s+(\S+)\s+(\S+)\s+(\S+)\s+\S+\s+(\S+)\s+(\S+)\s+/) {
	# Looks like a redhat driver ..
	local ($r, $rhs);
	foreach $r (&read_rhs_drivers()) {
		$rhs = $r if ($r->{'name'} eq $5);
		}
	local (%general, %postscript, %textonly);
	&read_env_file("$sd/general.cfg", \%general);
	&read_env_file("$sd/postscript.cfg", \%postscript);
	&read_env_file("$sd/textonly.cfg", \%textonly);
	return { 'mode' => 1,
		 'gsdevice' => $postscript{'GSDEVICE'},
		 'res' => $postscript{'RESOLUTION'},
		 'paper' => $postscript{'PAPERSIZE'},
		 'gsopts' => $postscript{'EXTRA_GS_OPTIONS'},
		 'eof' => lc($textonly{'TEXT_SEND_EOF'}),
		 'nup' => $postscript{'NUP'},
		 'hmargin' => $postscript{'RTLFTMAR'},
		 'vmargin' => $postscript{'TOPBOTMAR'},
		 'crlf' => $textonly{'CRLFTRANS'},
		 'bpp' => $postscript{'COLOR'} =~ /-dBitsPerPixel=(\d+)/ ? $1
				: $postscript{'COLOR'},
		 'rhsname' => $rhs->{'name'},
		 'desc' => $rhs->{'desc'} };
	}
else {
	# Some other kind of driver
	return { 'mode' => 2,
		 'file' => $_[0],
		 'desc' => $_[0] };
	}
}

# create_windows_driver(&printer, &driver)
# Creates a new windows printer driver
sub create_windows_driver
{
local $sd = "$config{'spool_dir'}/$_[0]->{'name'}";

# Create the config file and driver
local %sconfig;
&read_env_file("$sd/.config", \%sconfig);
$sconfig{'share'} = "\\\\$_[1]->{'server'}\\$_[1]->{'share'}";
$sconfig{'hostip'} = $_[1]->{'server'} eq $config{'hostip'} ?
			$sconfig{'hostip'} : undef;
$sconfig{'user'} = $_[1]->{'user'};
$sconfig{'password'} = $_[1]->{'pass'};
$sconfig{'workgroup'} = $_[1]->{'workgroup'};
&lock_file($sd);
mkdir($sd, 0755);
&unlock_file($sd);
&open_lock_tempfile(ENV, ">$sd/.config");
&print_tempfile(ENV, "share='$sconfig{'share'}'\n");
&print_tempfile(ENV, "hostip=$sconfig{'hostip'}\n");
&print_tempfile(ENV, "user='$sconfig{'user'}'\n");
&print_tempfile(ENV, "password='$sconfig{'password'}'\n");
&print_tempfile(ENV, "workgroup='$sconfig{'workgroup'}'\n");
&close_tempfile(ENV);

# Setup the comment and return the driver
local $drv = &is_driver($_[1]->{'program'}, $_[0]);
if ($drv->{'mode'} == 1) {
	local %general;
	&lock_file("$sd/general.cfg");
	&read_env_file("$sd/general.cfg", \%general);
	$general{'PRINTER_TYPE'} = 'SMB';
	&write_env_file("$sd/general.cfg", \%general, 1);
	&unlock_file("$sd/general.cfg");
	$_[0]->{'comment'} =~ s/\s+LOCAL\s+/ SMB /;
	return $_[1]->{'program'};
	}
else {
	$_[0]->{'comment'} = "##PRINTTOOL3## SMB";
	return $smb_driver;
	}
}

# create_driver(&printer, &driver)
# Creates a new local printer driver and returns the path
sub create_driver
{
local ($prn, $drv) = @_;
if ($drv->{'mode'} == 0) {
	$prn->{'comment'} =
		join(" ", "##PRINTTOOL3##",
			  $prn->{'rhost'} ? "REMOTE" : "LOCAL");
	return undef;
	}
elsif ($drv->{'mode'} == 2) {
	$prn->{'comment'} =
		join(" ", "##PRINTTOOL3##",
			  $prn->{'rhost'} ? "REMOTE" : "LOCAL");
	return $drv->{'file'};
	}
else {
	if (!-d $config{'spool_dir'}) {
		&lock_file($config{'spool_dir'});
		mkdir($config{'spool_dir'}, 0755);
		&unlock_file($config{'spool_dir'});
		&system_logged("chown $config{'iface_owner'} $config{'spool_dir'}");
		}
	local $sd = "$config{'spool_dir'}/$_[0]->{'name'}";

	# create the config files
	local (%general, %postscript, %textonly);
	&lock_file("$sd/general.cfg");
	&lock_file("$sd/postscript.cfg");
	&lock_file("$sd/textonly.cfg");
	&read_env_file("$sd/general.cfg", \%general);
	&read_env_file("$sd/postscript.cfg", \%postscript);
	&read_env_file("$sd/textonly.cfg", \%textonly);
	if (!%general) {
		# setup for the first time..
		%general = ( 'DESIRED_TO', 'ps',
			     'ASCII_TO_PS', 'NO' );
		}
	$general{'PAPERSIZE'} = $drv->{'paper'};
	$general{'PRINTER_TYPE'} = $_[0]->{'rhost'} ? "REMOTE" : "LOCAL";
	$postscript{'GSDEVICE'} = $drv->{'gsdevice'};
	$postscript{'RESOLUTION'} = $drv->{'res'} ? $drv->{'res'} : "NAxNA";
	$postscript{'COLOR'} = $drv->{'bpp'} =~ /^\d+$/ ?
			"-dBitsPerPixel=$drv->{'bpp'}" : $drv->{'bpp'};
	$postscript{'PAPERSIZE'} = $drv->{'paper'};
	$postscript{'EXTRA_GS_OPTIONS'} = $drv->{'gsopts'};
	$postscript{'PS_SEND_EOF'} = uc($drv->{'eof'});
	$postscript{'NUP'} = $drv->{'nup'};
	$postscript{'RTLFTMAR'} = $drv->{'hmargin'};
	$postscript{'TOPBOTMAR'} = $drv->{'vmargin'};
	$textonly{'TEXT_SEND_EOF'} = uc($drv->{'eof'});
	$textonly{'CRLFTRANS'} = $drv->{'crlf'};
	&lock_file($sd);
	mkdir($sd, 0755);
	&unlock_file($sd);
	&write_env_file("$sd/general.cfg", \%general, 1);
	&write_env_file("$sd/postscript.cfg", \%postscript);
	&write_env_file("$sd/textonly.cfg", \%textonly);
	&unlock_file("$sd/general.cfg");
	&unlock_file("$sd/postscript.cfg");
	&unlock_file("$sd/textonly.cfg");

	# create the comment
	$_[0]->{'comment'} =
		join(" ", "##PRINTTOOL3##",
			  $_[0]->{'rhost'} ? "REMOTE" : "LOCAL",
			  $drv->{'gsdevice'},
			  $drv->{'res'} ? $drv->{'res'} : "NAxNA",
			  $drv->{'paper'},
			  "{}",
			  $drv->{'rhsname'},
			  $drv->{'bpp'} ? $drv->{'bpp'} : "Default",
			  $drv->{'crlf'} ? 1 : "{}" );

	# copy the standard filter into place
	&lock_file("$sd/filter");
	unlink("$sd/filter");
	&copy_source_dest("$base_driver", "$sd/filter");
	&unlock_file("$sd/filter");
	return "$sd/filter";
	}
}

# delete_driver(name)
sub delete_driver
{
local $sd = "$config{'spool_dir'}/$_[0]";
unlink("$sd/.config", "$sd/filter");
unlink("$sd/general.cfg", "$sd/postscript.cfg", "$sd/textonly.cfg");
}

# driver_input(&printer, &driver)
sub driver_input
{
local ($prn, $drv) = @_;

printf "<tr> <td><input type=radio name=mode value=0 %s> %s</td>\n",
	$drv->{'mode'} == 0 ? "checked" : "", $text{'redhat_none'};
print "<td>($text{'redhat_nonemsg'})</td> </tr>\n";

printf "<tr> <td><input type=radio name=mode value=2 %s> %s</td>\n",
	$drv->{'mode'} == 2 ? "checked" : "", $text{'redhat_prog'};
printf "<td><input name=iface value=\"%s\" size=35></td> </tr>\n",
	$drv->{'mode'} == 2 ? $drv->{'file'} : "";

printf "<tr> <td valign=top><input type=radio name=mode value=1 %s>\n",
	$drv->{'mode'} == 1 ? "checked" : "";
print "$text{'redhat_driver'}</td> <td><table width=100%>";

print "<tr> <td valign=top><b>$text{'redhat_printer'}</b></td>\n";
print "<td colspan=3><select size=5 name=gsdevice onChange='setres(0)'>\n";
local @rhs = &read_rhs_drivers();
local ($r, $select_res, $rr);
local $bpp = $drv->{'bpp'};
local $res = $drv->{'res'};
foreach $r (@rhs) {
	local @res;
	if ($r->{'res'} && $r->{'bpp'}) {
		foreach $rr (@{$r->{'res'}}) {
			push(@res, map { "$rr->[0]x$rr->[1], $_->[0] DPI, $_->[1]" } @{$r->{'bpp'}});
			}
		for($i=0; $i<@res; $i++) {
			$select_res = $i if ($res[$i] =~ /^$res, $bpp / &&
					     $drv->{'rhsname'} eq $r->{'name'});
			}
		}
	elsif ($r->{'res'}) {
		@res = map { "$_->[0]x$_->[1]" } @{$r->{'res'}};
		$select_res = &indexof($res, @res)
			if ($drv->{'rhsname'} eq $r->{'name'});
		}
	else {
		@res = map { "$_->[1], $_->[0]" } @{$r->{'bpp'}};
		for($i=0; $i<@res; $i++) {
			$select_res = $i if ($res[$i] =~ / $bpp$/ &&
					     $drv->{'rhsname'} eq $r->{'name'});
			}
		}
	printf "<option value='%s' %s>%s</option>\n",
		$r->{'name'}.";".join(";", @res),
		$drv->{'rhsname'} eq $r->{'name'} ? 'selected' : '',
		$r->{'desc'};
	}
print "</select><select size=5 name=res width=250>\n";
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'redhat_eof'}</b></td>\n";
printf "<td><input type=radio name=eof value=yes %s> $text{'yes'}\n",
	$drv->{'eof'} eq 'yes' ? 'checked' : '';
printf "<input type=radio name=eof value=no %s> $text{'no'}</td>\n",
	$drv->{'eof'} eq 'yes' ? '' : 'checked';

print "<td><b>$text{'redhat_paper'}</b></td> <td><select name=paper>\n";
foreach $p (sort { $a cmp $b } keys %paper_sizes) {
	printf "<option value='%s' %s>%s</option>\n",
		$p, $drv->{'paper'} eq $p ? 'selected' : '',
		$paper_sizes{$p};
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'redhat_pages'}</b></td>\n";
print "<td><select name=nup>\n";
foreach $p (1, 2, 4, 8) {
	printf "<option %s>%s</option>\n",
		$drv->{'nup'} == $p ? 'selected' : '', $p;
	}
print "</select></td>\n";

print "<td><b>$text{'redhat_gsopts'}</b></td>\n";
printf "<td><input name=gsopts size=30 value='%s'></td> </tr>\n",
	$drv->{'gsopts'};

print "<tr> <td><b>$text{'redhat_hmargin'}</b></td>\n";
printf "<td><input name=hmargin size=6 value='%s'></td>\n",
	$drv->{'hmargin'} ? $drv->{'hmargin'} : 18;

print "<td><b>$text{'redhat_vmargin'}</b></td>\n";
printf "<td><input name=vmargin size=6 value='%s'></td> </tr>\n",
	$drv->{'vmargin'} ? $drv->{'vmargin'} : 18;

print "<tr> <td><b>$text{'redhat_crlf'}</b></td>\n";
printf "<td><input type=radio name=crlf value=1 %s> $text{'yes'}\n",
	$drv->{'crlf'} ? 'checked' : '';
printf "<input type=radio name=crlf value=0 %s> $text{'no'}</td>\n",
	$drv->{'crlf'} ? '' : 'checked';

print "</table></td></tr>\n";

return <<EOF;
<script>
function setres(sel)
{
var idx = document.forms[0].gsdevice.selectedIndex;
var v = new String(document.forms[0].gsdevice.options[idx].value);
var vv = v.split(";");
var res = document.forms[0].res;
res.length = 0;
for(var i=1; i<vv.length; i++) {
	res.options[i-1] = new Option(vv[i], i-1);
	}
if (res.length > 0) {
	res.options[sel].selected = true;
	}
}
setres($select_res);
</script>
EOF

}

# parse_driver()
# Parse driver selection from %in and return a driver structure
sub parse_driver
{
if ($in{'mode'} == 0) {
	return { 'mode' => 0 };
	}
elsif ($in{'mode'} == 2) {
	(-x $in{'iface'}) || &error(&text('redhat_eprog', $in{'iface'}));
	return { 'mode' => 2,
		 'file' => $in{'iface'} };
	}
elsif ($in{'mode'} == 1) {
	$in{'gsdevice'} || &error($text{'redhat_edriver'});
	$in{'hmargin'} =~ /^\d+$/ ||
		&error($text{'redhat_ehmargin'});
	$in{'vmargin'} =~ /^\d+$/ ||
		&error($text{'redhat_evmargin'});
	local $drv = { 'mode' => 1,
		       'eof' => $in{'eof'},
		       'paper' => $in{'paper'},
		       'nup' => $in{'nup'},
		       'gsopts' => $in{'gsopts'},
		       'hmargin' => $in{'hmargin'},
		       'vmargin' => $in{'vmargin'},
		       'crlf' => $in{'crlf'} };

	local ($r, $rhs);
	$in{'gsdevice'} =~ s/;.*$//;
	foreach $r (&read_rhs_drivers()) {
		$rhs = $r if ($r->{'name'} eq $in{'gsdevice'});
		}
	if ($rhs->{'res'} && $rhs->{'bpp'}) {
		defined($in{'res'}) || &error($text{'redhat_eres'});
		local $bc = @{$rhs->{'bpp'}};
		local $rs = $rhs->{'res'}->[$in{'res'} / $bc];
		local $bp = $rhs->{'bpp'}->[$in{'res'} % $bc];
		$drv->{'res'} = $rs->[0].'x'.$rs->[1];
		$drv->{'bpp'} = $bp->[0];
		}
	elsif ($rhs->{'res'}) {
		defined($in{'res'}) || &error($text{'redhat_eres'});
		local $rs = $rhs->{'res'}->[$in{'res'}];
		$drv->{'res'} = $rs->[0].'x'.$rs->[1];
		}
	elsif ($rhs->{'bpp'}) {
		defined($in{'res'}) || &error($text{'redhat_eres'});
		$drv->{'bpp'} = $rhs->{'bpp'}->[$in{'res'}]->[0];
		}
	$drv->{'rhsname'} = $rhs->{'name'};
	$drv->{'gsdevice'} = $rhs->{'gsdriver'};
	return $drv;
	}
}

sub read_rhs_drivers
{
local (@rv, $drv);
open(DRV, $rhs_drivers_file);
while(<DRV>) {
	s/#.*$//g;
	s/\r|\n//g;
	if (/^\s*StartEntry:\s+(.*)/) {
		push(@rv, $drv = { 'name' => $1 });
		}
	elsif (/^\s*GSDriver:\s+(\S+)/) {
		$drv->{'gsdriver'} = $1;
		}
	elsif (/^\s*Description:\s+{(.*)}/) {
		$drv->{'desc'} = $1;
		}
	elsif (/^\s*Resolution:\s+{(\d+)}\s+{(\d+)}/) {
		push(@{$drv->{'res'}}, [ $1, $2 ]);
		}
	elsif (/^\s*BitsPerPixel:\s+{(\S+)}\s+{(.*)}/) {
		push(@{$drv->{'bpp'}}, [ $1, $2 ]);
		}
	}
close(DRV);
return @rv;
}

1;

