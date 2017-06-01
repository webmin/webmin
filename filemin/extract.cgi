#!/usr/local/bin/perl

require './filemin-lib.pl';
use lib './lib';
use File::MimeInfo;

&ReadParse();

get_paths();

$archive_type = mimetype($cwd.'/'.$in{'file'});

if ($archive_type =~ /x-bzip/) {
	$cmd = "tar xvjfp ".quotemeta("$cwd/$in{'file'}").
	       " -C ".quotemeta($cwd);
	}
elsif ($archive_type =~ /x-tar|\/gzip|x-xz|x-compressed-tar/) {
	$cmd = "tar xfp ".quotemeta("$cwd/$in{'file'}").
	       " -C ".quotemeta($cwd);
	}
elsif ($archive_type =~ /x-7z/) {
	$cmd = "7z x ".quotemeta("$cwd/$in{'file'}")." -o" .quotemeta($cwd);
	}
elsif ($archive_type =~ /\/zip/) {
	$cmd = "unzip ".quotemeta("$cwd/$in{'file'}")." -d ".quotemeta($cwd);
	}
elsif ($archive_type =~ /\/x-rar/) {
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
