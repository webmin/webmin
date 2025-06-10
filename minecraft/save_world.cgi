#!/usr/local/bin/perl
# Create or delete a world

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text, %config);
if ($ENV{'CONTENT_TYPE'} =~ /boundary=/) {
	&ReadParseMime();
	}
else {
	&ReadParse();
	}
my @worlds = &list_worlds();
my $conf = &get_minecraft_config();
my $def = &find_value("level-name", $conf);
&error_setup($in{'new'} ? $text{'world_err1'} : $text{'world_err2'});

if ($in{'new'}) {
	# Validate new world inputs
	$in{'name'} =~ /^[a-z0-9\.\_\-]+$/i || &error($text{'world_ename'});
	my ($clash) = grep { $_->{'name'} eq $in{'name'} } @worlds;
	$clash && &error($text{'world_eclash'});
	my $dir = "$config{'minecraft_dir'}/$in{'name'}";
	-e $dir && &error($text{'world_eclash2'});

	# Create world directory
	if ($in{'src'} == 0) {
		# Empty world
		&make_dir($dir, 0755);
		my $fh = "EMPTY";
		&open_tempfile($fh, ">$dir/level.dat", 0, 1);
		&close_tempfile($fh);
		&set_ownership_permissions($config{'unix_user'}, undef, 0755,
					   $dir, "$dir/level.dat");
		}
	elsif ($in{'src'} == 1) {
		# Clone existing world
		if (&is_minecraft_server_running() &&
		    $def eq $in{'world'}) {
			# Flush state to disk
			&execute_minecraft_command("save-all");
			&execute_minecraft_command("save-off");
			}
		&copy_source_dest("$config{'minecraft_dir'}/$in{'world'}",
				  $dir);
		&system_logged(
			"chown -R $config{'unix_user'} ".quotemeta($dir));
		if (&is_minecraft_server_running() &&
		    $def eq $in{'world'}) {
			# Re-enable world writes
			&execute_minecraft_command("save-on");
			}
		}
	elsif ($in{'src'} == 2 || $in{'src'} == 3) {
		# From uploaded or local file
		my $temp = &transname();
		if ($in{'src'} == 2) {
			$in{'upload'} || &error($text{'world_eupload'});
			my $fh = "ZIP";
			&open_tempfile($fh, ">$temp", 0, 1);
			&print_tempfile($fh, $in{'upload'});
			&close_tempfile($fh);
			}
		else {
			$in{'file'} || &error($text{'world_efile'});
			-r $in{'file'} || &error($text{'world_efile2'});
			&copy_source_dest($in{'file'}, $temp);
			}
		my $out = &backquote_command("file ".$temp);
		$out =~ /Zip\s+archive/i || &error($text{'world_ezip'});
		my $tempdir = &transname();
		&make_dir($tempdir, 0755);
		$out = &backquote_command("cd $tempdir && unzip $temp");
		$? && &error(&text('world_eunzip', $out));
		my $dat = "$tempdir/level.dat";
		if (!-r $dat) {
			($dat) = glob("$tempdir/*/level.dat");
			}
		-r $dat && $dat =~ /^(.*)\/level.dat$/ ||
			&error($text{'world_edat'});
		my $copysrc = $1;
		&copy_source_dest($copysrc, $dir);
		&system_logged(
			"chown -R $config{'unix_user'} ".quotemeta($dir));
		}
	&redirect("list_worlds.cgi");
	}
elsif ($in{'delete'} && $in{'confirm'}) {
	# Delete the world
	$in{'name'} || &error("Missing world name");
	my $dir = "$config{'minecraft_dir'}/$in{'name'}";
	&unlink_logged($dir);
	&redirect("list_worlds.cgi");
	}
elsif ($in{'delete'}) {
	# Ask first before deleting
	$in{'name'} || &error("Missing world name");
	$def eq $in{'name'} && &error($text{'world_einuse'});
	&ui_print_header(undef, $text{'world_edit'}, "");

	print &ui_confirmation_form(
		"save_world.cgi",
		&text('world_rusure', "<tt>$in{'name'}</tt>"),
		[ [ "name", $in{'name'} ],
		  [ "delete", 1 ] ],
		[ [ "confirm", $text{'world_confirm'} ] ],
		);

	&ui_print_footer("list_worlds.cgi", $text{'worlds_return'});
	}
elsif ($in{'download'} && !$ENV{'PATH_INFO'}) {
	# Redirect to download with a nice path
	&redirect("save_world.cgi/$in{'name'}.zip?name=$in{'name'}&download=1");
	}
elsif ($in{'download'} && $ENV{'PATH_INFO'}) {
	# Download world as ZIP file
	$in{'name'} || &error("Missing world name");
	if (&is_minecraft_server_running() &&
	    $def eq $in{'name'}) {
		# Flush state to disk
		&execute_minecraft_command("save-off");
		&execute_minecraft_command("save-all");
		}
	my $temp = &transname().".zip";
	my $out = &backquote_command(
		"cd ".quotemeta($config{'minecraft_dir'})." && ".
	        "zip -r $temp ".quotemeta($in{'name'}));
	my $ex = $?;
	if (&is_minecraft_server_running() &&
	    $def eq $in{'name'}) {
		# Re-enable world writes
		&execute_minecraft_command("save-on");
		}
	my @st = stat($temp);
	!$ex && @st ||
	    &error(&text('world_ezip', "<tt>".&html_escape($out)."</tt>"));
	print "Content-type: application/zip\n";
	print "Content-length: $st[7]\n";
	print "X-no-links: 1\n";
	print "Content-Disposition: Attachment\n";
	print "\n";
	my $fh = "ZIP";
	my $buf;
        &open_readfile($fh, $temp);
        &unlink_file($temp);
        while(read($fh, $buf, 1024)) {
                print $buf;
                }
        close($fh);
	}
else {
	&error("No button clicked");
	}
