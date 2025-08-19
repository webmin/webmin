# csw-lib.pl
# Functions for installing packages from Blastwave

$pkg_get = -x "/opt/csw/bin/pkgutil" ? "/opt/csw/bin/pkgutil" :
	   -x "/opt/csw/bin/pkg-get" ? "/opt/csw/bin/pkg-get" :
	   &has_command("pkgutil") ? &has_command("pkgutil") :
				     &has_command("pkg-get");

sub list_update_system_commands
{
return ($pkg_get);
}

# update_system_install([file])
# Install some package with pkg-get
sub update_system_install
{
local $update = $_[0] || $in{'update'};
local (@rv, @newpacks, %seen, $failed);

# Setup for non-interactive mode
&copy_source_dest("/var/pkg-get/admin", "/var/pkg-get/admin-old");
&copy_source_dest("/var/pkg-get/admin-fullauto", "/var/pkg-get/admin");

# Run pkg-get
$| = 1;
local ($failed, $retry, %already);
do {
	if ($already{$update}++) {
		# Don't try the same update twice
		last;
		}
	local $flag = $pkg_get =~ /pkgutil$/ ? "-y" : "-f";
	print &text('csw_install',
			"<tt>$pkg_get -i $flag $update</tt>"),"\n";
	$failed = 0;
	$retry = 0;
	print "<pre data-installer>";
	&open_execute_command(PKGGET,
		"$pkg_get -i $flag ".quotemeta($update), 2);
	while(<PKGGET>) {
		if (!/\s*\d+\%\s+\[/) {
			# Output everything except download lines
			print &html_escape($_);
			}
		if (/Installation of <(.*)> was successful/i) {
			push(@rv, $1);
			}
		elsif (/Installation of <(.*)> failed/i) {
			$failed = 1;
			}
		elsif (/dependency\s+(\S+)\s+.*not up to date/i) {
			# Needs a dependency .. so we will need to re-run!
			local $dep = $1;
			$update = join(" ", &unique(
					$dep, split(/\s+/, $update)));
			$retry = 1;
			}
		elsif (/you already have version/i) {
			$failed = 2;
			}
		}
	close(PKGGET);
	print "</pre>";

	if ($retry) {
		print "$text{'csw_retry'}<p>\n";
		}
	} while ($retry);

# Cleanup fullout file
&copy_source_dest("/var/pkg-get/admin-old", "/var/pkg-get/admin");

if ($failed == 1) {
	print "$text{'csw_failed'}<p>\n";
	return ( );
	}
elsif ($failed == 2) {
	print "$text{'csw_already'}<p>\n";
	return ( );
	}
else {
	print "$text{'csw_ok'}<p>\n";
	if (!@rv) {
		# If nothing failed, assume that everything worked
		@rv = split(/\s+/, $update);
		}
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
	if (/^\s*(\S+)\s+(\S+)\s+(\d\S+)\s+([0-9\.]+)\s+(KB|MB|GB|B)/i) {
		# New pkgutil format
		push(@rv, { 'name' => $1, 'version' => $3,
			    'select' => "$1-$3" });
		}
	elsif (/^\s*(\S+)\s+(\S+)/) {
		# Old pkg-get format
		push(@rv, { 'name' => $1, 'version' => $2,
			    'select' => "$1-$2" });
		}
	}
close(PKG);
return sort { lc($a->{'name'}) cmp lc($b->{'name'}) } @rv;
}

1;

