#!/usr/local/bin/perl
# install-module.pl
# Install a single module file

# Check arguments
$nodeps = 0;
if ($ARGV[0] eq "--nodeps") {
	shift(@ARGV);
	$nodeps = 1;
	}
while($ARGV[0] eq "--acl") {
	shift(@ARGV);
	push(@grant, shift(@ARGV));
	}
if (@ARGV > 2 || !@ARGV) {
	die "usage: install-module.pl [--nodeps] [--acl user]* <module.wbm> [config_directory]";
	}
$file = $ARGV[0];
$config = $ARGV[1] ? $ARGV[1] : "/etc/webmin";
-r $file || die "$file does not exist";
open(CONF, "$config/miniserv.conf") ||
	die "Failed to read $config/miniserv.conf - maybe $config is not a Webmin config directory";
while(<CONF>) {
	s/\r|\n//g;
	if (/^root=(.*)/) {
		$root = $1;
		}
	}
close(CONF);
-d $root || die "Webmin directory $root does not exist";
chop($var = `cat $config/var-path`);

if ($file !~ /^\//) {
	chop($pwd = `pwd`);
	$file = "$pwd/$file";
	}

# Set up webmin environment
push(@INC, ".", $root);
$ENV{'WEBMIN_CONFIG'} = $config;
$ENV{'WEBMIN_VAR'} = $var;
$no_acl_check++;
chdir($root);
$0 = "$root/install-module.pl";
eval "use WebminCore;";
&init_config();

# Install it, using the standard function
&foreign_require("webmin", "webmin-lib.pl");
if (@grant) {
	$newusers = \@grant;
	}
else {
	$newusers = &webmin::get_newmodule_users();
	$newusers ||= [ "root", "admin" ];
	}
$rv = &webmin::install_webmin_module($file, 0, $nodeps, $newusers);
if (ref($rv)) {
	for($i=0; $i<@{$rv->[0]}; $i++) {
		printf "Installed %s in %s (%d kb)\n",
			$rv->[0]->[$i],
			$rv->[1]->[$i],
			$rv->[2]->[$i];
		}
	}
else {
	$rv =~ s/<[^>]+>//g;
	print STDERR "Install failed : $rv\n";
	}

