#!/usr/local/bin/perl
# create_htaccess.cgi
# Creates a new .htaccess file for some directory

require './apache-lib.pl';
&error_setup($text{'htaccess_err'});
&ReadParse();
$access{'global'} || &error($text{'htaccess_ecannot'});
$conf = &get_config();
$in{'file'} || &error($text{'htaccess_eempty'});
$in{'file'} =~ /^\// && $in{'file'} !~ /\.\./ ||
	&error($text{'htaccess_eabsolute'});

if (-d $in{'file'}) {
	# user entered a directory.. create a file in that directory
	$accfile = &find_directive("AccessFile", $conf);
	if (!$accfile) { $accfile = ".htaccess"; }
	$file = "$in{'file'}/$accfile";
	}
else {
	$file = $in{'file'};
	}
&allowed_auth_file($file) ||
	&error($text{'htaccess_ecreate'});

# create the file (if needed), and add to the known list
&lock_file($file);
if (!(-r $file)) {
	&open_tempfile(HTACCESS, ">$file");
	&close_tempfile(HTACCESS);
	chmod(0755, $file);

	$u = &find_directive("User", $conf);
	if ($u =~ /#(\d+)/) { $u = $1; }
	elsif (defined($u)) { $u = getpwnam($u); }

	$g = &find_directive("Group", $conf);
	if ($g =~ /#(\d+)/) { $g = $1; }
	elsif (defined($g)) { $g = getgrnam($g); }

	chown(defined($u) ? $u : $< , defined($g) ? $g : $( , $file);
	}
&read_file("$module_config_directory/site", \%site);
@ht = split(/\s+/, $site{'htaccess'});
$site{'htaccess'} = join(' ', &unique(@ht, $file));
&write_file("$module_config_directory/site", \%site);
&unlock_file($file);
&webmin_log("htaccess", "create", $file);

# redirect to editing index
&redirect("htaccess_index.cgi?file=".&urlize($file));

