#!/usr/bin/perl

require './filemin-lib.pl';
&ReadParse();
get_paths();

if(!$in{'arch'}) {
    &redirect("index.cgi?path=$path");
}

my $command;

if($in{'method'} eq 'tar') {
    $command = "tar czf ".quotemeta("$cwd/$in{'arch'}.tar.gz").
	       " -C ".quotemeta($cwd);
} elsif($in{'method'} eq 'zip') {
    $command = "cd ".quotemeta($cwd)." && zip -r ".
	       quotemeta("$cwd/$in{'arch'}.zip");
}

foreach my $name(split(/\0/, $in{'name'}))
{
    $name =~ s/$in{'cwd'}\///ig;
    $command .= " ".quotemeta($name);
}

system_logged($command);

&redirect("index.cgi?path=$path");
