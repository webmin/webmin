# apt-lib.pl
# Functions for installing packages from debian APT

$apt_get_command = $config{'apt_mode'} ? "aptitude" : "apt-get";
$apt_search_command = $config{'apt_mode'} ? "aptitude" : "apt-cache";

# update_system_install([package])
# Install some package with apt
sub update_system_install
{
local (@rv, @newpacks);
local $update = $_[0] || $in{'update'};
local $cmd = $apt_get_command eq "apt-get" ?
	"$apt_get_command -y --force-yes -f install $update" :
	"$apt_get_command -y -f install $update";
print "<b>",&text('apt_install', "<tt>$cmd</tt>"),"</b><p>\n";
print "<pre>";
$update = join(" ", map { quotemeta($_) } split(/\s+/, $update));
&additional_log('exec', undef, $cmd);
&open_execute_command(CMD, "yes Yes | $cmd 2>&1", 1);
while(<CMD>) {
	if (/setting\s+up\s+(\S+)/i && !/as\s+MDA/i) {
		push(@rv, $1);
		}
	elsif (/packages\s+will\s+be\s+upgraded/i ||
	       /new\s+packages\s+will\s+be\s+installed/i) {
		print;
		$line = $_ = <CMD>;
		$line =~ s/^\s+//; $line =~ s/\s+$//;
		push(@newpacks, split(/\s+/, $line));
		}
	print;
	}
close(CMD);
if (!@rv && $config{'package_system'} ne 'debian' && !$?) {
	# Other systems don't list the packages installed!
	@rv = @newpacks;
	}
print "</pre>\n";
if ($?) { print "<b>$text{'apt_failed'}</b><p>\n"; }
else { print "<b>$text{'apt_ok'}</b><p>\n"; }
return @rv;
}

# update_system_form()
# Shows a form for updating all packages on the system
sub update_system_form
{
print &ui_subheading($text{'apt_form'});
print &ui_form_start("apt_upgrade.cgi");
print &ui_table_start($text{'apt_header'}, undef, 2);

print &ui_table_row($text{'apt_update'},
	&ui_yesno_radio("update", 1));

print &ui_table_row($text{'apt_mode'},
	&ui_radio("mode", 0, [ [ 2, $text{'apt_mode2'} ],
			       [ 1, $text{'apt_mode1'} ],
			       [ 0, $text{'apt_mode0'} ] ]));

print &ui_table_row($text{'apt_sim'},
	&ui_yesno_radio("sim", 0));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'apt_apply'} ] ]);
}

# update_system_resolve(name)
# Converts a standard package name like apache, sendmail or squid into
# the name used by APT.
sub update_system_resolve
{
local ($name) = @_;
return $name eq "dhcpd" ? "dhcp3-server" :
       $name eq "bind" ? "bind9" :
       $name eq "mysql" ? "mysql-client mysql-server mysql-admin" :
       $name eq "apache" ? "apache2" :
       $name eq "postgresql" ? "postgresql postgresql-client" :
       $name eq "openssh" ? "ssh" :
       $name eq "openldap" ? "slapd" :
			       $name;
}

# update_system_available()
# Returns a list of package names and versions that are available from YUM
sub update_system_available
{
local (@rv, $pkg);
&execute_command("$apt_get_command update");
&open_execute_command(DUMP, "apt-cache dump", 1, 1);
while(<DUMP>) {
	if (/^\s*Package:\s*(\S+)/) {
		$pkg = { 'name' => $1 };
		push(@rv, $pkg);
		}
	elsif (/^\s*Version:\s*(\S+)/ && $pkg && !$pkg->{'version'}) {
		$pkg->{'version'} = $1;
		if ($pkg->{'version'} =~ /^(\d+):(.*)$/) {
			$pkg->{'epoch'} = $1;
			$pkg->{'version'} = $2;
			}
		}
	}
close(DUMP);
return @rv;
}

# update_system_search(text)
# Returns a list of packages matching some search
sub update_system_search
{
local (@rv, $pkg);
&open_execute_command(DUMP, "$apt_search_command search ".quotemeta($_[0]), 1, 1);
while(<DUMP>) {
	if (/^(\S+)\s*-\s*(.*)/) {
		push(@rv, { 'name' => $1, 'desc' => $2 });
		}
	elsif (/^(\S)\s+(\S+)\s+-\s*(.*)/) {
		push(@rv, { 'name' => $2, 'desc' => $3 });
		}
	}
close(DUMP);
return @rv;
}


