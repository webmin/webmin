#!/usr/local/bin/perl
# find_htaccess.cgi
# Finds all per-directory options files under the all the document roots

require './apache-lib.pl';
&ReadParse();
$access{'global'} || &error($text{'htaccess_ecannot'});

$in{'from'}=1 if ($access{'dir'} ne '/');
if ($in{'from'} == 1 && !(-d $in{'dir'})) {
	&error(&text('htaccess_edir', $in{'dir'}));
	}
&read_file("$module_config_directory/site", \%site);
foreach $f (split(/\s+/, $site{'htaccess'})) {
	if (-r $f) { push(@rv, $f); }
	}

# Find the default document root and access file
$conf = &get_config();
$def_htaccess = &find_directive("AccessFileName", $conf);
if (!$def_htaccess) { $def_htaccess = ".htaccess"; }
$def_root = &find_directive("DocumentRoot", $conf);
if (!$def_root) { $def_root = "/"; }

# find virtual server doc roots and access files
push(@dirs, $def_root); push(@files, $def_htaccess);
foreach $v (&find_directive_struct("VirtualHost", $conf)) {
	$root = &find_directive("DocumentRoot", $v->{'members'});
	push(@dirs, $root ? $root : $def_root);
	$htaccess = &find_directive("AccessFileName", $v->{'members'});
	push(@files, $htaccess ? $htaccess : $def_htaccess);
	}

if ($in{'from'} == 0) {
	# search under all directories
	for($i=0; $i<@dirs; $i++) {
		open(FIND, "find ".quotemeta($dirs[$i]).
			   " -name ".quotemeta($files[$i])." -print |");
		while(<FIND>) {
			s/\r|\n//g;
			push(@rv, $_);
			}
		close(FIND);
		}
	}
else {
	# search under the given directory only
	foreach $f (&unique(@files)) {
		push(@args, "-name ".quotemeta($f));
		}
	$args = join(' -o ', @args);
	open(FIND, "find ".quotemeta($in{'dir'})." $args -print |");
	while(<FIND>) {
		s/\r|\n//g;
		push(@rv, $_);
		}
	close(FIND);
	}

# save results
$site{'htaccess'} = join(' ', &unique(@rv));
&write_file("$module_config_directory/site", \%site);
&redirect("htaccess.cgi");

