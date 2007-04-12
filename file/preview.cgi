#!/usr/local/bin/perl
# Scale some image down to the preview size

require './file-lib.pl';
&ReadParse();
use POSIX;
$p = $ENV{'PATH_INFO'};

# Try to guess type from filename
$type = &guess_mime_type($p, undef);
if (!$type) {
	# No idea .. use the 'file' command
	$out = &backquote_command("file ".
				  quotemeta(&resolve_links($p)), 1);
	if ($out =~ /text|script/) {
		$type = "text/plain";
		}
	else {
		&error_exit(&text('preview_etype', $p));
		}
	}

# Make sure the type is OK
if ($type ne "image/gif" && $type ne "image/jpeg" && $type ne "image/png" &&
    $type ne "image/tiff" && $type ne "application/pdf" &&
    $type !~ /^image\/x-portable/ && $type ne "application/postscript") {
	&error_exit(&text('preview_etype2', $p));
	}

&switch_acl_uid_and_chroot();
if (!&can_access($p)) {
	# ACL rules prevent access to file
	&error_exit(&text('view_eaccess', $p));
	}

# Test if the file can be opened
if (!open(FILE, $p)) {
	# Unix permissions prevent access
	&error_exit(&text('view_eopen', $p, $!));
	}
close(FILE);

eval "use GD";
if ($@ || $type eq "image/tiff" || $type eq "application/pdf" ||
          $type =~ /^image\/x-portable/ || $type eq "application/postscript") {
	# Find an appropriate scaler
	$pnmcmd = $type eq "image/gif" ? "giftopnm" :
		  $type eq "image/jpeg" ? "djpeg" :
		  $type eq "image/png" ? "pngtopnm" :
		  $type eq "image/tiff" ? "tifftopnm" :
		  $type =~ /^image\/x-portable/ ? "cat" :
		  $type eq "application/postscript" ? "pstopnm" :
		  $type eq "application/pdf" ? "pdftoppm" :
					  undef;
	&has_command($pnmcmd) ||
		&error_exit(&text('preview_ecmd', $pnmcmd));
	&has_command("pnmscale") ||
		&error_exit(&text('preview_ecmd', "pnmscale"));
	&has_command("cjpeg") ||
		&error_exit(&text('preview_ecmd', "cjpeg"));

	# Run scaler
	$width = $config{'width'} || $userconfig{'width'} || 300;
	$errout = &transname();
	print "Content-type: image/jpeg\n";
	print "\n";
	if ($type eq "application/pdf") {
		# Previewing first page of PDF
		$temp = &tempname();
		$out = &backquote_command("$pnmcmd -f 1 -l 1 ".quotemeta($p)." ".$temp." 2>&1");
		if ($? || !-r "$temp-000001.ppm") {
			&error_exit("$pnmcmd failed : $out");
			}
		open(SCALE, "(cat $temp-000001.ppm | pnmscale --width $width | cjpeg) 2>$errout |");
		push(@main::temporary_files, "$temp-000001.ppm");
		}
	elsif ($type eq "application/postscript") {
		# Previewing first page of a postscript file
		$temp = &transname();
		mkdir($temp, 0755);
		&copy_source_dest($p, "$temp/file.ps");
		$out = &backquote_command("$pnmcmd $temp/file.ps 2>&1");
		if ($? || !-r "$temp/file001.ppm") {
			&error_exit("$pnmcmd failed : $out");
			}
		open(SCALE, "(cat $temp/file001.ppm | pnmscale --width $width | cjpeg) 2>$errout |");
		}
	else {
		# Converting to JPEG
		open(SCALE, "($pnmcmd <".quotemeta($p)." | pnmscale --width $width | cjpeg) 2>$errout |");
		}
	$err = &read_file_contents($errout);
	print STDERR $err;
	while(<SCALE>) {
		print;
		}
	close(SCALE);
	}
else {
	# Use the GD library
	$image = $type eq "image/gif" ? GD::Image->newFromGif($p) :
		 $type eq "image/jpeg" ? GD::Image->newFromJpeg($p) :
		 $type eq "image/png" ? GD::Image->newFromPng($p) : undef;
	$image || &error_exit(&text('preview_egd'));

	$width = $config{'width'} || $userconfig{'width'} || 300;
	$height = $image->height * (($width*1.0) / $image->width);

	$scaled = new GD::Image($width, $height);
	$scaled->copyResampled($image, 0, 0, 0, 0, $width, $height,
			       $image->width, $image->height);
	print "Content-type: image/jpeg\n";
	print "\n";
	print $scaled->jpeg();
	}

sub error_exit
{
print "Content-type: text/plain\n";
print "Content-length: ",length($_[0]),"\n\n";
print $_[0];
exit;
}

