# rhn-lib.pl
# Functions for installing packages from the redhat network

$up2date_config = "/etc/sysconfig/rhn/up2date";
$rhn_sysconfig = "/etc/sysconfig/rhn/rhnsd";

# update_system_install([package])
# Install some package with up2date
sub update_system_install
{
local $update = $_[0] || $in{'update'};
local @rv;
print "<b>",&text('rhn_install', "<tt>up2date $update</tt>"),"</b><p>\n";
print "<pre>";
&additional_log('exec', undef, "up2date \"$update\"");
local $qm = quotemeta($update);
&open_execute_command(CMD, "up2date $qm 2>&1", 1);
local $got_error = 0;
while(<CMD>) {
	while(s/^[^\015]+\015([^\012])/$1/) { }
	$got_error++ if (/error|failed/i);
	if (/installing.*\/([^\/\s]+)\-([^\-]+)\-([^\-]+)\.rpm/i) {
		push(@rv, $1);
		}
	print;
	}
close(CMD);
print "</pre>\n";
if ($got_error) {
	print "<b>$text{'rhn_failed'}</b><p>\n";
	@rv = ( );
	}
else {
	print "<b>$text{'rhn_ok'}</b><p>\n";
	}
return @rv;
}

# update_system_form()
# Show a form for configuring the redhat update agent
sub update_system_form
{
print &ui_subheading($text{'rhn_form'});
print "<form action=rhn_check.cgi>\n";
print "<table>\n";

&foreign_require("init", "init-lib.pl");
local $auto = &init::action_status("rhnsd");
print "<tr> <td><b>$text{'rhn_auto'}</b></td>\n";
printf "<td><input type=radio name=auto value=1 %s> %s\n",
	$auto == 2 ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=auto value=0 %s> %s</td> </tr>\n",
	$auto == 2 ? '' : 'checked', $text{'no'};

local %rhnsd;
&read_env_file($rhn_sysconfig, \%rhnsd);
print "<tr> <td><b>$text{'rhn_interval'}</b></td>\n";
print "<td><input name=interval size=5 value='$rhnsd{'INTERVAL'}'> ",
      "$text{'rhn_secs'}</td> </tr>\n";

local $conf = &read_up2date_config();
print "<tr> <td><b>$text{'rhn_proxy'}</b></td>\n";
printf "<td><input type=radio name=proxy_on value=0 %s> %s\n",
	$conf->{'enableProxy'}->{'value'} ? '' : 'checked', $text{'rhn_none'};
printf "<input type=radio name=proxy_on value=1 %s> %s\n",
	$conf->{'enableProxy'}->{'value'} ? 'checked' : '';
local $prx = $conf->{'pkgProxy'} ? $conf->{'pkgProxy'}->{'value'}
				 : $conf->{'httpProxy'}->{'value'};
printf "<input name=proxy size=40 value='%s'></td> </tr>\n", $prx;

print "<tr> <td valign=top><b>$text{'rhn_skip'}</b></td>\n";
print "<td><textarea name=skip rows=3 cols=40>",
      join("\n", split(/;/, $conf->{'pkgSkipList'}->{'value'})),
      "</textarea></td> </tr>\n";

print "</table>\n";
print "<input type=submit value='$text{'rhn_apply'}'>\n";
print "<input type=submit name=now value='$text{'rhn_now'}'></form>\n";
}

# read_up2date_config()
sub read_up2date_config
{
local %conf;
local $lnum = 0;
&open_readfile(CONF, $up2date_config);
while(<CONF>) {
	s/\r|\n//g; s/#.*$//;
	if (/^([^=\s]+)=(.*)$/) {
		$conf{$1} = { 'name' => $1,
			      'value' => $2,
			      'line' => $lnum };
		}
	$lnum++;
	}
close(CONF);
return \%conf;
}

# save_up2date_config(&config, name, value)
sub save_up2date_config
{
local $lref = &read_file_lines($up2date_config);
local $old = $_[0]->{$_[1]};
if ($old) {
	$lref->[$old->{'line'}] = "$_[1]=$_[2]";
	}
}

# update_system_available()
# Returns a list of packages available from RHN
sub update_system_available
{
local @rv;
open(UP2DATE, "up2date -l --showall |");
while(<UP2DATE>) {
	s/\r|\n//g;
	if (/^(\S+)\-([^\-]+)\-([^\-]+)\.([^\.]+)$/) {
		push(@rv, { 'name' => $1,
			    'version' => "$2-$3",
			    'arch' => $4 });
		}
	}
close(UP2DATE);
return @rv;
}

1;

