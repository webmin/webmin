#!/usr/local/bin/perl

require './filemin-lib.pl';
&ReadParse();
get_paths();

if (!$in{'arch'}) {
	&redirect("index.cgi?path=".&urlize($path));
	return;
	}

my $command;
my $full;
my $extension;

if ($in{'method'} eq 'plain-tar') {
	$extension = ".tar";
	$full = &validate_filename_path($in{'arch'}.$extension);
	$command = "tar cf ".quotemeta($full).
		" -C ".quotemeta($cwd);
	}
elsif ($in{'method'} eq 'xz-tar') {
	$extension = ".tar.xz";
	$full = &validate_filename_path($in{'arch'}.$extension);
	$command = "tar cJf ".quotemeta($full).
		" -C ".quotemeta($cwd);
	}
elsif ($in{'method'} eq 'zstd-tar') {
	$extension = ".zst";
	$full = &validate_filename_path($in{'arch'}.$extension);
	$command = "ZSTD_CLEVEL=19 tar --zstd -cf ".
		quotemeta($full).
		" -C ".quotemeta($cwd);
	}
elsif ($in{'method'} eq 'tar') {
	$extension = ".tar.gz";
	$full = &validate_filename_path($in{'arch'}.$extension);
	$command = "tar czf ".quotemeta($full).
		" -C ".quotemeta($cwd);
	}
elsif ($in{'method'} eq 'zip') {
	$extension = ".zip";
	$full = &validate_filename_path($in{'arch'}.$extension);
	$command = "cd ".quotemeta($cwd).
		" && zip -r ".quotemeta($full);
	}
else {
	&error("Unknown method!");
	}
$newfile = !-e $full;

foreach my $name (split(/\0/, $in{'name'})) {
	my $full_name = &validate_filename_path($name);
	my $relative_name = $full_name;
	$relative_name =~ s/^\Q$cwd\E\/?//;
	$command .= " ".quotemeta($relative_name);
	}

my @st = stat($cwd);
&system_logged($command);
if ($newfile) {
	&set_ownership_permissions(
		$st[4], $st[5], undef, $full);
	}

&redirect("index.cgi?path=".&urlize($path));
