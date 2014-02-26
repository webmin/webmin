# printconf-driver.pl
# Functions for printer drivers as created by redhat 7.1

$mf_wrapper = "/usr/share/printconf/mf_wrapper";
@overview_files = ( "/usr/share/printconf/foomatic/data/00-overview.foo",
		    "/usr/share/printconf/foomatic/rh-data/00-overview.foo" );
$mfomatic = "/usr/share/printconf/foomatic/mfomatic";
$ps_wrapper= "/usr/share/printconf/util/mf_postscript_wrapper";
$text_filter = "pipe/postscript/ /usr/bin/mpage -b ifdef(`PAGEsize', PAGEsize, Letter) -1 -o -P- -";
$default_filter = "cat/text/";
$smb_driver = "/usr/share/printconf/smbprint";

@paper_sizes = ( 'Letter', 'Legal', 'Executive',
		 'A5', 'A4', 'A3' );

# is_windows_driver(path, &printer)
# Returns a driver structure if some path is a windows driver
sub is_windows_driver
{
local $sd = "$config{'spool_dir'}/$_[1]->{'name'}";
if ($_[1]->{'dev'} eq "|$smb_driver" && -r "$sd/script.cfg") {
	# Looks like a redhat SMB driver
	local %sconfig;
	&read_env_file("$sd/script.cfg", \%sconfig);
	$sconfig{'share'} =~ /^\\\\(.*)\\(.*)$/;
	return { 'server' => $1,
		 'share' => $2,
		 'user' => $sconfig{'user'},
		 'pass' => $sconfig{'password'},
		 'workgroup' => $sconfig{'workgroup'},
		 'program' => $_[0] };
	}
return undef;

}

# is_driver(path, &printer)
# Returns a structure containing the details of a driver
# XXX do we need to support old redhat drivers?
sub is_driver
{
if (!$_[0]) {
	return { 'mode' => 0,
		 'desc' => "$text{'redhat_none'}" };
	}
local $sd = "$config{'spool_dir'}/$_[1]->{'name'}";
if ($_[0] eq $mf_wrapper && -r "$sd/mf.cfg") {
	# Looks like a new printconf driver
	local %define;
	&read_m4_file("$sd/mf.cfg", \%define);
	if ($define{'PSfilter'} =~
	    /^filter\s+$ps_wrapper.*\s(\S+)-(\d+)\.foo$/) {
		# Has printer driver
		return { 'mode' => 1,
			 'driver' => $1,
			 'id' => $2,
			 'paper' => $define{'PAGEsize'},
			 'make' => $define{'MAKE'},
			 'model' => $define{'MODEL'},
			 'desc' => "$define{'MAKE'} $define{'MODEL'}" };
		}
	elsif ($define{'PSfilter'} =~ /^filter\s+$ps_wrapper\s*$/) {
		# Postscript printer
		return { 'mode' => 1,
			 'postscript' => 1,
			 'paper' => $define{'PAGEsize'},
			 'desc' => 'Postscript printer' };
		}
	elsif ($define{'PSfilter'} eq 'text' &&
	       $define{'TEXTfilter'} eq 'text') {
		# Text only printer
		return { 'mode' => 1,
			 'text' => 1,
			 'desc' => 'Text printer' };
		}
	}

# Some other kind of driver
return { 'mode' => 2,
	 'file' => $_[0],
	 'desc' => $_[0] };
}

# read_m4_file(file, &hash)
sub read_m4_file
{
open(CFG, $_[0]);
while(<CFG>) {
	s/#.*$//; s/\r|\n//g;
	if (/^\s*define\(([A-Za-z0-9\_]+)\s*,\s*`([^']*)'\)/) {
		$_[1]->{$1} = $2;
		}
	elsif (/^\s*define\(([A-Za-z0-9\_]+)\s*,\s*([^\s\)]+)\)/) {
		$_[1]->{$1} = $2;
		}
	}
close(CFG);
}

# create_windows_driver(&printer, &driver)
# Creates a new windows printer driver
sub create_windows_driver
{
local $sd = "$config{'spool_dir'}/$_[0]->{'name'}";

# Create the config file and driver
local %sconfig;
&read_file("$sd/script.cfg", \%sconfig);
$sconfig{'share'} = "\\\\$_[1]->{'server'}\\$_[1]->{'share'}";
$sconfig{'hostip'} = $_[1]->{'server'} eq $config{'hostip'} ?
			$sconfig{'hostip'} : undef;
$sconfig{'user'} = $_[1]->{'user'};
$sconfig{'password'} = $_[1]->{'pass'};
$sconfig{'workgroup'} = $_[1]->{'workgroup'};
&lock_file($sd);
mkdir($sd, 0755);
&unlock_file($sd);
&open_lock_tempfile(ENV, ">$sd/script.cfg");
&print_tempfile(ENV, "share='$sconfig{'share'}'\n");
&print_tempfile(ENV, "hostip=$sconfig{'hostip'}\n");
&print_tempfile(ENV, "user='$sconfig{'user'}'\n");
&print_tempfile(ENV, "password='$sconfig{'password'}'\n");
&print_tempfile(ENV, "workgroup='$sconfig{'workgroup'}'\n");
&close_tempfile(ENV);

# Set the print device
$_[0]->{'dev'} = "|$smb_driver";
return $_[1]->{'program'};
}

# create_driver(&printer, &driver)
# Creates a new local printer driver and returns the path
sub create_driver
{
local ($prn, $drv) = @_;
if ($drv->{'mode'} == 0) {
	return undef;
	}
elsif ($drv->{'mode'} == 2) {
	return $drv->{'file'};
	}
else {
	# Create the config file
	local $sd = "$config{'spool_dir'}/$_[0]->{'name'}";
	mkdir($sd, 0755);
	&lock_file("$sd/mf.cfg");
	if ($drv->{'text'}) {
		%driver = ( 'MAKE', '',
			    'MODEL', '',
			    'COLOR', '',
			    'PAGEsize', $_[1]->{'paper'},
			    'TEXTfilter', 'text',
			    'PSfilter', 'text',
			    'PCLfilter', 'reject',
			    'PJLfilter', 'reject',
			    'DEFAULTfilter', $default_filter );
		}
	elsif ($drv->{'postscript'}) {
		%driver = ( 'MAKE', '',
			    'MODEL', '',
			    'COLOR', '',
			    'PAGEsize', $_[1]->{'paper'},
			    'TEXTfilter', $text_filter,
			    'PSfilter', "filter $ps_wrapper ",
			    'PCLfilter', 'cat',
			    'PJLfilter', 'cat',
			    'DEFAULTfilter', $default_filter );
		}
	else {
		local $base = "$drv->{'driver'}-$drv->{'id'}.foo";
		local $path;
		foreach $f (@overview_files) {
			local $d = $f; $d =~ s/\/[^\/]+$//;
			$path = "$d/$base" if (-r "$d/$base");
			}
		&system_logged("cp $path $sd");
		&read_m4_file("$sd/mf.cfg", \%driver);
		$driver{'MAKE'} = $drv->{'make'};
		$driver{'MODEL'} = $drv->{'model'};
		$driver{'COLOR'} = 'true';	# ???
		$driver{'PSfilter'} = "filter $ps_wrapper --mfomatic -d $base";
		$driver{'TEXTfilter'} = $text_filter;
		$driver{'PCLfilter'} = 'cat';
		$driver{'PJLfilter'} = 'cat';
		$driver{'PAGEsize'} = $_[1]->{'paper'};
		$driver{'DEFAULTfilter'} = $default_filter;
		}
	&open_tempfile(CFG, ">$sd/mf.cfg");
	foreach $d (keys %driver) {
		if ($driver{$d} =~ /`|'/) {
			&print_tempfile(CFG, "define($d, $driver{$d})dnl\n");
			}
		else {
			&print_tempfile(CFG, "define($d, `$driver{$d}')dnl\n");
			}
		}
	&close_tempfile(CFG);
	&unlock_file("$sd/mf.cfg");
	return $mf_wrapper;
	}
}

# delete_driver(name)
sub delete_driver
{
local $sd = "$config{'spool_dir'}/$_[0]";
unlink("$sd/mf.cfg", "$sd/account");
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

print "<tr> <td valign=top><b>$text{'redhat_printer2'}</b></td>\n";
print "<td><select name=printer size=10 onChange='setdriver(0)'>\n";
printf "<option value=%s %s>%s</option>\n",
	'text', $drv->{'text'} ? 'selected' : '', "Text printer";
printf "<option value=%s %s>%s</option>\n",
	'postscript', $drv->{'postscript'} ? 'selected' : '',
	"Postscript printer";

local $list = &list_printconf_drivers();
local $select_driver = 0;
foreach $k (sort { lc($a) cmp lc($b) } keys %$list) {
	foreach $m (@{$list->{$k}}) {
		next if (!@{$m->{'drivers'}});
		printf "<option value='%s' %s>%s</option>\n",
			join(";", $m->{'id'}, @{$m->{'drivers'}}),
			$drv->{'make'} eq $k &&
			$drv->{'model'} eq $m->{'model'} ? 'selected' : '',
			"$k $m->{'model'}";
		if ($drv->{'make'} eq $k && $drv->{'model'} eq $m->{'model'}) {
			$select_driver = &indexof($drv->{'driver'},
						  @{$m->{'drivers'}});
			}
		}
	}
print "</select><select name=driver size=10 width=100></select></td> </tr>\n";

local $foundp = 0;
print "<tr> <td><b>$text{'redhat_paper'}</b></td> <td><select name=paper>\n";
print "<option value='' selected>$text{'redhat_none'}</option>\n" if (!$drv->{'paper'});
foreach $p (@paper_sizes) {
	printf "<option %s>%s</option>\n",
		$drv->{'paper'} eq $p ? 'selected' : '', $p;
	$foundp++ if ($drv->{'paper'} eq $p);
	}
printf "<option selected>$drv->{'paper'}</option>\n" if (!$foundp && $drv->{'paper'});
print "</select></td> </tr>\n";

print "</table></td></tr>\n";
return <<EOF;
<script>
function setdriver(sel)
{
var idx = document.forms[0].printer.selectedIndex;
var v = new String(document.forms[0].printer.options[idx].value);
var vv = v.split(";");
var driver = document.forms[0].driver;
driver.length = 0;
for(var i=1; i<vv.length; i++) {
	driver.options[i-1] = new Option(vv[i], vv[i]);
	}
if (driver.length > 0) {
	driver.options[sel].selected = true;
	}
}
setdriver($select_driver);
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
else {
	$in{'printer'} || &error($text{'redhat_edriver'});
	if ($in{'printer'} eq 'text') {
		return { 'mode' => 1,
			 'paper' => $in{'paper'},
			 'text' => 1 };
		}
	elsif ($in{'printer'} eq 'postscript') {
		return { 'mode' => 1,
			 'paper' => $in{'paper'},
			 'postscript' => 1 };
		}
	else {
		$in{'driver'} || &error($text{'redhat_edriver'});
		local @p = split(/;/, $in{'printer'});
		local $list = &list_printconf_drivers();
		local ($make, $model);
		foreach $k (keys %$list) {
			foreach $m (@{$list->{$k}}) {
				if ($m->{'id'} == $p[0]) {
					$make = $k;
					$model = $m->{'model'};
					}
				}
			}
		return { 'mode' => 1,
			 'paper' => $in{'paper'},
			 'id' => $p[0],
			 'make' => $make,
			 'model' => $model,
			 'driver' => $in{'driver'} };
		}
	}
}

# list_printconf_drivers()
sub list_printconf_drivers
{
local %rv;
foreach $ov (@overview_files) {
	next if (!-r $ov);
	local $VAR1;
	eval { do $ov };
	next if ($@);
	foreach $k (keys %$VAR1) {
		foreach $m (@{$VAR1->{$k}}) {
			push(@{$rv{$k}}, $m);
			}
		}
	}
return \%rv;
}

