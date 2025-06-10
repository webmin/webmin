#!/usr/local/bin/perl

require './filemin-lib.pl';

&ReadParse();

get_paths();

$archive_type = clean_mimetype($cwd.'/'.$in{'file'});

if ($archive_type =~ /x-bzip/) {
	$cmd = "tar xvjfp ".quotemeta("$cwd/$in{'file'}").
	       " -C ".quotemeta($cwd);
	}
elsif ($archive_type =~ /x-tar|\/gzip|x-xz|zstd|x-compressed-tar/) {
	$cmd = "tar xfp ".quotemeta("$cwd/$in{'file'}").
	       " -C ".quotemeta($cwd);
	}
elsif ($archive_type =~ /x-7z/ ||
	   $archive_type =~ /x-raw-disk-image/ ||
	   $archive_type =~ /x-cd-image/) {
	$cmd = "7z x ".quotemeta("$cwd/$in{'file'}")." -o" .quotemeta($cwd);
	}
elsif ($archive_type =~ /\/zip/) {
	my $unzip_out = `unzip --help`;
	my $uu = ($unzip_out =~ /-UU/ ? '-UU' : undef);
	$cmd = "unzip $uu -q -o ".quotemeta("$cwd/$in{'file'}")." -d ".quotemeta($cwd);
	}
elsif ($archive_type =~ /\/x-rar|\/vnd\.rar/) {
	$cmd = "unrar x -r -y ".quotemeta("$cwd/$in{'file'}").
	       " ".quotemeta($cwd);
	}
elsif ($archive_type =~ /(\/x-rpm|\/x-deb)/) {
	my $dir = fileparse( "$cwd/$name", qr/\.[^.]*/ );
	my $path = quotemeta("$cwd/$dir");
	&make_dir($path, 0755);
	if ($archive_type =~ /\/x-rpm/) {
		$cmd = "(rpm2cpio ".quotemeta("$cwd/$name").
		       " | (cd ".quotemeta($path)."; cpio -idmv))";
		}
	else {
		$cmd = "dpkg -x ".quotemeta("$cwd/$name")." ".quotemeta($path);
		}
	}
else {
	&error($text{'extract_etype'});
	}

# Run the extraction command
$out = &backquote_logged("$cmd 2>&1 >/dev/null </dev/null");
if ($?) {
	&error(&html_escape($out));
	}

&redirect("index.cgi?path=".&urlize($path));
