# rhn-lib.pl
# Functions for installing packages from the redhat network

$up2date_config = "/etc/sysconfig/rhn/up2date";
$rhn_sysconfig = "/etc/sysconfig/rhn/rhnsd";

sub list_update_system_commands
{
return ("up2date");
}

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
&open_execute_command(CMD, "up2date $qm", 2);
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
print &ui_form_start("rhn_check.cgi");
print &ui_table_start($text{'rhn_header'}, undef, 2);

# Started at boot?
&foreign_require("init", "init-lib.pl");
local $auto = &init::action_status("rhnsd");
print &ui_table_row($text{'rhn_auto'},
	&ui_yesno_radio("auto", $auto == 2 ? 1 : 0));

# Checking interval
local %rhnsd;
&read_env_file($rhn_sysconfig, \%rhnsd);
print &ui_table_row($text{'rhn_interval'},
	&ui_textbox("interval", $rhnsd{'INTERVAL'}, 5)." ".$text{'rhn_secs'});

# Proxy server
local $conf = &read_up2date_config();
local $prx = $conf->{'pkgProxy'} ? $conf->{'pkgProxy'}->{'value'}
				 : $conf->{'httpProxy'}->{'value'};
print &ui_table_row($text{'rhn_proxy'},
	&ui_radio("proxy_on", $conf->{'enableProxy'}->{'value'} ? 1 : 0,
		  [ [ 0, $text{'rhn_none'} ],
		    [ 1, &ui_textbox("proxy", $prx, 40) ] ]));

# Packages to skip
print &ui_table_row($text{'rhn_skip'},
	&ui_textarea("skip",
	  join("\n", split(/;/, $conf->{'pkgSkipList'}->{'value'})), 5, 40));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'rhn_apply'} ],
		     [ "now", $text{'rhn_now'} ] ]);
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

