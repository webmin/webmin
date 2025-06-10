#!/usr/local/bin/perl
# save_dir.cgi
# Create or update a .htaccess file

require './htaccess-lib.pl';
&ReadParse();
$can_create || &error($text{'dir_ecannotcreate'});
@dirs = &list_directories();
&error_setup($text{'dir_err'});
&foreign_require($apachemod, "apache-lib.pl");

# Work out what .htaccess file to use
$in{'dir'} =~ s/\\/\//g;	# use forward slashes
if ($in{'new'} && $in{'dir'} !~ /^([a-z]:)?\//i && $default_dir ne "/") {
	# Make path absolute
	$in{'dir'} = "$default_dir/$in{'dir'}";
	}
($dir) = grep { $_->[0] eq $in{'dir'} } @dirs;
if ($in{'new'}) {
	$dir && &error($text{'dir_eclash'});
	$htaccess = "$in{'dir'}/$config{'htaccess'}";
	}
else {
	$htaccess = "$dir->[0]/$config{'htaccess'}";
	}

# Check for button that redirects to the Apache module for editing all
# options in .htaccess file
if ($in{'apache'}) {
	&redirect("../apache/htaccess_index.cgi?file=".
		  &urlize($htaccess));
	exit;
	}

&lock_file($htaccess);
&lock_file($directories_file);

# Get the apache directives for the .htaccess file, if any
$authz = $apache::httpd_modules{'mod_auth_digest'} >= 2.2;
$auf = $in{'crypt'} == 3 && !$authz ? "AuthDigestFile" : "AuthUserFile";
$agf = $in{'crypt'} == 3 && !$authz ? "AuthDigestGroupFile" : "AuthGroupFile";
$conf = &foreign_call($apachemod, "get_htaccess_config", $htaccess);
$currfile = &foreign_call($apachemod, "find_directive",
			  $auf, $conf, 1);
$currgfile = &foreign_call($apachemod, "find_directive",
			   $agf, $conf, 1);
&lock_file($currfile) if ($currfile);

# Make sure it is allowed, and create new file if needed
&switch_user();
&can_access_dir($htaccess) || &error($text{'dir_ecannot'});
$missing = !-r $htaccess;
&open_tempfile(TEST, ">>$htaccess", 1) || &error(&text('dir_ehtaccess', $htaccess, $!));
&close_tempfile(TEST);
if ($missing) {
	&set_ownership_permissions(
		undef, undef, oct($config{'perms'}) || 0644, $htaccess);
	}

if ($in{'delete'} || $in{'remove'}) {
	if ($in{'remove'}) {
		# Blow away .htaccess, htpasswd and htgroups
		&unlink_logged($htaccess);
		&unlink_logged($currfile) if ($currfile && !-d $currfile);
		&unlink_logged($currgfile) if ($currgfile && !-d $currgfile);
		}
	else {
		# Take the authentication directives out of .htaccess
		&foreign_call($apachemod, "save_directive",
			      "require", [ ], $conf, $conf);
		}
	@dirs = grep { $_ ne $dir } @dirs;
	}
else {
	# Validate inputs
	if ($in{'new'}) {
		$in{'dir'} =~ /^([a-z]:)?\// && -d $in{'dir'} ||
			&error($text{'dir_edir'});
		}

	# Parse users file option
	if (!$can_htpasswd) {
		# Users file is always automatic
		$file = $in{'new'} ? "$in{'dir'}/$config{'htpasswd'}"
				   : $dir->[1];
		}
	elsif ($in{'auto'}) {
		# User choose for it to be automatic
		$file = "$in{'dir'}/$config{'htpasswd'}";
		}
	else {
		# Entered by user
		$in{'file'} || &error($text{'dir_efile'});
		if ($in{'file'} !~ /^([a-z]:)?\//) {
			$file = "$in{'dir'}/$in{'file'}";
			}
		else {
			$file = $in{'file'};
			}
		}
	-d $file && &error(&text('dir_efiledir', $file));

	# Parse groups file option
	if (!$can_htgroups) {
		# Groups file is always fixed, or none
		$gfile = $in{'new'} ? undef : $dir->[3];
		}
	elsif ($in{'gauto'} == 2) {
		# No groups file
		$gfile = undef;
		}
	elsif ($in{'gauto'} == 1) {
		# User choose for groups file to be automatic
		$gfile = "$in{'dir'}/$config{'htgroups'}";
		}
	else {
		# Groups file was entered by user
		$in{'file'} || &error($text{'dir_egfile'});
		if ($in{'gfile'} !~ /^([a-z]:)?\//) {
			$gfile = "$in{'dir'}/$in{'gfile'}";
			}
		else {
			$gfile = $in{'gfile'};
			}
		}
	-d $gfile && &error(&text('dir_egfiledir', $gfile));

	# Parse require option
	@require = ( $in{'require_mode'} );
	if ($in{'require_mode'} eq "user") {
		@users = split(/\s+/, $in{'require_user'});
		@users || &error($text{'dir_erequire_user'});
		push(@require, @users);
		}
	elsif ($in{'require_mode'} eq "group") {
		@groups = split(/\s+/, $in{'require_group'});
		@groups || &error($text{'dir_erequire_group'});
		push(@require, @groups);
		}

	# Parse Webmin sync
	$sync = join(",", grep { $in{'sync_'.$_} }
			       ('create', 'update', 'delete'));
	$sync ||= "-";

	if ($in{'new'}) {
		# Either update an existing .htaccess to ensure that all
		# needed directives exist, or create from scratch

		# Use the existing users path if there is one, otherwise add
		$currfile = &foreign_call($apachemod, "find_directive",
					  $auf, $conf, 1);
		if ($currfile) {
			$file = $currfile;
			}
		else {
			&foreign_call($apachemod, "save_directive",
				      $auf, [ "\"$file\"" ], $conf, $conf);
			}

		# Use the existing groups path if there is one, otherwise add
		$currgfile = &foreign_call($apachemod, "find_directive",
					   $agf, $conf, 1);
		if ($currgfile) {
			$gfile = $currgfile;
			}
		elsif ($gfile) {
			&foreign_call($apachemod, "save_directive",
				      $agf, [ "\"$gfile\"" ], $conf,$conf);
			}

		# Add an auth type if needed
		$currtype = &foreign_call($apachemod, "find_directive",
					  "AuthType", $conf, 1);
		if (!$currtype) {
			&foreign_call($apachemod, "save_directive",
				     "AuthType",
				     [ $in{'crypt'} == 3 ? "Digest" : "Basic" ],
				     $conf, $conf);
			}

		# Add a realm if needed
		$currrealm = &foreign_call($apachemod, "find_directive",
					   "AuthName", $conf, 1);
		if (!$currrealm) {
			$in{'realm'} || &error($text{'dir_erealm'});
			&foreign_call($apachemod, "save_directive", "AuthName",
				      [ "\"$in{'realm'}\"" ], $conf, $conf);
			}

		# Add a require if needed
		$currrequire = &foreign_call($apachemod, "find_directive",
					     "require", $conf, 1);
		if (!$currrequire) {
			&foreign_call($apachemod, "save_directive",
				      "require", [ join(" ", @require) ],
						$conf, $conf);
			}

		# Add AuthDigestProvider if needed
		if ($authz && $in{'crypt'} == 3) {
			&foreign_call($apachemod, "save_directive",
				      "AuthDigestProvider",
				      [ "file" ], $conf, $conf);
			}

                # Add 'extra directives' if needed
                local $edline;
                foreach $edline (split(/\t+/, $config{'extra_directives'})) {
                        local ($ed, $edval);
                        $edline =~ m/(.*?)\s+(.*)/;
                        ($ed, $edval) = ($1, $2);
                        $curred = &foreign_call($apachemod, "find_directive",
                                                         $ed, $conf);
                        if (!$curred) {
                                &foreign_call($apachemod, "save_directive",
					  $ed, [$edval], $conf, $conf);
                                }
                        }

		# Add to the known directories list
		$sync = "-" if (!$can_sync);
		$dir = [ $in{'dir'}, $file, $in{'crypt'}, $sync, $gfile ];
		push(@dirs, $dir);
		}
	else {
		# Just update the users and groups file paths, realm and
		# require directive
		&foreign_call($apachemod, "save_directive",
			      $auf, [ $file ],
					$conf, $conf);
		&foreign_call($apachemod, "save_directive",
			      $agf, $gfile ? [ $gfile ] : [ ],
					$conf, $conf);
		&foreign_call($apachemod, "save_directive",
			      "AuthName", [ "\"$in{'realm'}\"" ],
					$conf, $conf);
		&foreign_call($apachemod, "save_directive",
			      "require", [ join(" ", @require) ],
					$conf, $conf);

		# Update the known directories list
		$dir->[1] = $file;
		$dir->[2] = $in{'crypt'};
		$dir->[3] = $sync if ($can_sync);
		$dir->[4] = $gfile;
		}

	# Create an empty users file if needed
	if (!-r $file) {
		&lock_file($file);
		&open_tempfile(FILE, ">$file", 1, 1) ||
			&error(&text('dir_ehtpasswd', $file, $!));
		&close_tempfile(FILE) ||
			&error(&text('dir_ehtpasswd', $file, $!));
		&unlock_file($file);
		&set_ownership_permissions(
			undef, undef, oct($config{'perms'}) || 0644, $file);
		}

	# Create an empty groups file if needed
	if ($gfile && !-r $gfile) {
		&lock_file($gfile);
		&open_tempfile(FILE, ">$gfile", 1, 1) ||
			&error(&text('dir_ehtgroup', $gfile, $!));
		&close_tempfile(FILE) ||
			&error(&text('dir_ehtgroup', $gfile, $!));
		&unlock_file($gfile);
		&set_ownership_permissions(
			undef, undef, oct($config{'perms'}) || 0644, $gfile);
		}
	}

&flush_file_lines();
&switch_back();

&save_directories(\@dirs);
&unlock_all_files();
&webmin_log($in{'delete'} || $in{'remove'} ? "delete" :
	    $in{'new'} ? "create" : "modify",
	    "dir", $dir->[0]);
&redirect("");

