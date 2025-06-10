#!/usr/local/bin/perl

require './filemin-lib.pl';
&ReadParse();
get_paths();

if(!$in{'arch'}) {
	&redirect("index.cgi?path=".&urlize($path));
	return;
	}

my $command;

if ($in{'method'} eq 'plain-tar') {
	$full = "$cwd/$in{'arch'}.tar";
	$command = "tar cf ".quotemeta($full)." -C ".quotemeta($cwd);
	}
elsif ($in{'method'} eq 'xz-tar') {
	$full = "$cwd/$in{'arch'}.tar.xz";
	$command = "tar cJf ".quotemeta($full)." -C ".quotemeta($cwd);
	}
elsif ($in{'method'} eq 'zstd-tar') {
	$full = "$cwd/$in{'arch'}.zst";
	$command = "ZSTD_CLEVEL=19 tar --zstd -cf ".quotemeta($full)." -C ".quotemeta($cwd);
	}
elsif ($in{'method'} eq 'tar') {
	$full = "$cwd/$in{'arch'}.tar.gz";
	$command = "tar czf ".quotemeta($full)." -C ".quotemeta($cwd);
	}
elsif ($in{'method'} eq 'zip') {
	$full = "$cwd/$in{'arch'}.zip";
	$command = "cd ".quotemeta($cwd)." && zip -r ".quotemeta($full);
	}
else {
	&error("Unknown method!");
	}
$newfile = !-e $full;

foreach my $name (split(/\0/, $in{'name'})) {
	$command .= " ".quotemeta($name);
	}

my @st = stat($cwd);
&system_logged($command);
if ($newfile) {
	&set_ownership_permissions($st[4], $st[5], undef, $full);
	}

&redirect("index.cgi?path=".&urlize($path));
