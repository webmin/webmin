# csw-lib.pl
# Functions for installing packages from Blastwave

$pkg_get = -x "/opt/csw/bin/pkg-get" ? "/opt/csw/bin/pkg-get"
				     : &has_command("pkg-get");

# update_system_install([file])
# Install some package with pkg-get
sub update_system_install
{
local $update = $_[0] || $in{'update'};
local (@rv, @newpacks);
print "<b>",&text('csw_install', "<tt>$pkg_get -i $update</tt>"),"</b><p>\n";
$| = 1;
print "<pre>";
local ($ph, $ppid) = &foreign_call("proc", "pty_process_exec_logged",
				   "$pkg_get -i ".quotemeta($update));
while(1) {
	local $wf = &wait_for($ph, '(.*) \[\S+\]',
			     'Installation of <(.*)> failed',
			     'Installation of <(.*)> was successful',
			     'No changes were made to the system',
			     '.*\n', '.*\r');
	if ($wait_for_input !~ /^\s*\d+\%\s+\[/) {
		# Print everything except download line
		print &html_escape($wait_for_input);
		}
	if ($wf == 0) {
		# some question which should not have appeared before
		if ($seen{$matches[1]}++) {
			$failed++;
			last;
			}
		&sysprint($ph, "y\n");
		}
	elsif ($wf == 1) {
		# This package contains scripts
		$failed++;
		last;
		}
	elsif ($wf == 1 || $wf == 3) {
		# failed for some reason.. give up
		$failed++;
		last;
		}
	elsif ($wf == 2) {
		# done ok!
		push(@rv, $matches[1]);
		}
	elsif ($wf == -1) {
		# No more output
		last;
		}
	}
print "</pre>";
close($ph);
if ($? || $failed) {
	print "<b>$text{'csw_failed'}</b><p>\n";
	return ( );
	}
else {
	print "<b>$text{'csw_ok'}</b><p>\n";
	return @rv;
	}
}

# update_system_available()
# Returns a list of all available CSW packages
sub update_system_available
{
local @rv;
open(PKG, "$pkg_get -a |");
while(<PKG>) {
	s/\r|\n//g;
	s/#.*$//;
	next if (/^\s*WARNING:/);
	if (/^\s*(\S+)\s+(\S+)/) {
		push(@rv, { 'name' => $1, 'version' => $2,
			    'select' => "$1-$2" });
		}
	}
close(PKG);
return sort { lc($a->{'name'}) cmp lc($b->{'name'}) } @rv;
}


