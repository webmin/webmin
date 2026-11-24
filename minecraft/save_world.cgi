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
&error_setup($in{'new'} ? $text{'world_err1'} :
	     $in{'download'} ? $text{'world_errdownload'} : $text{'world_err2'});
# Clone, download and delete only existing world directories.
if (!$in{'new'} || $in{'src'} == 1) {
	my $name = $in{'new'} ? $in{'world'} : $in{'name'};
	defined($name) && length($name) && $name !~ /[\x00\r\n\/]|^\.\.?\z/ ||
		&error($text{'world_ename'});
	(grep { $_->{'name'} eq $name } @worlds) || &error($text{'world_ename'});
	}

if ($in{'new'}) {
	# Validate new world inputs
	$in{'name'} =~ /^[a-z0-9._-]+\z/i && $in{'name'} !~ /^\.\.?\z/ ||
		&error($text{'world_ename'});
	my ($clash) = grep { $_->{'name'} eq $in{'name'} } @worlds;
	$clash && &error($text{'world_eclash'});
	my $dir = "$config{'minecraft_dir'}/$in{'name'}";
	(-e $dir || -l $dir) && &error($text{'world_eclash2'});

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
	# The active world may have changed since the confirmation was shown.
	$def eq $in{'name'} && &error($text{'world_einuse'});
	my $dir = "$config{'minecraft_dir'}/$in{'name'}";
	&unlink_logged($dir);
	&redirect("list_worlds.cgi");
	}
elsif ($in{'delete'}) {
	# Ask first before deleting
	$def eq $in{'name'} && &error($text{'world_einuse'});
	&ui_print_header(undef, $text{'world_edit'}, "");

	print &ui_confirmation_form(
		"save_world.cgi",
		&text('world_rusure', "<tt>".&html_escape($in{'name'})."</tt>"),
		[ [ "name", $in{'name'} ],
		  [ "delete", 1 ] ],
		[ [ "confirm", $text{'world_confirm'} ] ],
		);

	&ui_print_footer("list_worlds.cgi", $text{'worlds_return'});
	}
elsif ($in{'download'} && !$ENV{'PATH_INFO'}) {
	# Report a linked world before redirecting to its download URL.
	&error($text{'world_elink'}) if (-l "$config{'minecraft_dir'}/$in{'name'}");
	my $name = &urlize($in{'name'});
	&redirect("save_world.cgi/$name.zip?name=$name&download=1");
	}
elsif ($in{'download'} && $ENV{'PATH_INFO'}) {
	# Download world as ZIP file
	my $temp = &transname().".zip";
	my $err = &create_world_zip($in{'name'}, $temp, $def);
	if (defined($err)) {
		&unlink_file($temp) if (-f $temp);
		&error(&html_escape($err));
		}
	my @st = stat($temp);
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
