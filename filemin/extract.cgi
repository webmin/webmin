#!/usr/local/bin/perl

require './filemin-lib.pl';

&ReadParse();

get_paths();
&check_allowed_path($cwd);

my $name = $in{'file'};
my $full = &validate_filename_path($name);
$archive_type = clean_mimetype($full);

# Most commands extract into the current directory, which is a private
# directory that is then merged into the target
my $target = $cwd;
my ($rpm, $tar_archive);
my $overwrite = 1;
if ($archive_type =~ /x-bzip/) {
	$tar_archive = $full;
	$cmd = "tar xvjfp ".quotemeta($full);
	}
elsif ($archive_type =~
       /x-tar|\/gzip|x-xz|zstd|x-compressed-tar/) {
	$tar_archive = $full;
	$cmd = "tar xfp ".quotemeta($full);
	}
elsif ($archive_type =~ /x-7z/ ||
       $archive_type =~ /x-raw-disk-image/ ||
       $archive_type =~ /x-cd-image/) {
	$cmd = "7z x ".quotemeta($full)." -o.";
	# 7z needs confirmation to overwrite and this CGI has no input.
	$overwrite = undef;
	}
elsif ($archive_type =~ /\/zip/) {
	my $unzip_out = `unzip --help`;
	my $uu = ($unzip_out =~ /-UU/ ? '-UU' : undef);
	$cmd = "unzip $uu -q -o -d . -- ".quotemeta($full);
	}
elsif ($archive_type =~ /\/x-rar|\/vnd\.rar/) {
	$cmd = "unrar x -r -y ".quotemeta($full)." ./";
	}
elsif ($archive_type =~ /\/x-(source-)?rpm/) {
	# bsdtar reads RPMs directly and rejects paths through directory symlinks
	my ($dir) = fileparse($full, qr/\.[^.]*/);
	my $target = &validate_filename_path($dir);
	$cmd = &rpm_extract_command($full, $target);
	$cmd || &error(&text('extract_missing_bsdtar', &html_escape($name)));
	# Never extract through an existing symlink
	-l $target && &error(&text('extract_edir', &html_escape($target)));
	&make_dir($target, 0755);
	$rpm = 1;
	}
elsif ($archive_type =~ /\/x-deb/) {
	my ($dir) = fileparse($full, qr/\.[^.]*/);
	$target = &validate_filename_path($dir);
	&make_dir($target, 0755) if (!-l $target);
	$cmd = "dpkg -x ".quotemeta($full)." .";
	}
else {
	&error($text{'extract_etype'});
	}

# Run the extraction command
if ($rpm) {
	$out = &backquote_logged(
		"$cmd 2>&1 >/dev/null </dev/null");
	if ($?) {
		&error(&html_escape($out));
		}
	}
else {
	my ($status, @errors) = &extract_in_private_dir($target, $overwrite, sub {
		$out = &backquote_logged(
			"$cmd 2>&1 >/dev/null </dev/null");
		return $?;
		}, undef, undef, $tar_archive);
	if ($status && $out =~ /\S/) {
		unshift(@errors, &html_escape($out));
		}
	if ($status || @errors) {
		&error(join("<br>\n", @errors));
		}
	}

&redirect("index.cgi?path=".&urlize($path));
