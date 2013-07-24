#!/usr/local/bin/perl
# Create zh_TW.UTF-8 files from zh_TW.Big5 files, and zh_CN.UTF-8 files from
# zh_CN files, ja_JP.UTF-8 from ja_JP.euc, and ko_KR.UTF-8 from ko_KR.euc
#
# Also creates ru.UTF-8 from ru_SU files

chdir($ARGV[0] || "/usr/local/webadmin");
@modules = ( "." );
opendir(DIR, ".");
foreach $d (readdir(DIR)) {
	push(@modules, $d) if (-r "$d/module.info");
	}
closedir(DIR);

open(LANG, "lang_list.txt");
while(<LANG>) {
	if (/^(\S+)\s+(.*)/) {
		my $l = { 'desc' => $2 };
		foreach $o (split(/,/, $1)) {
			if ($o =~ /^([^=]+)=(.*)$/) {
				$l->{$1} = $2;
				}
			}
		$l->{'index'} = scalar(@rv);
		push(@langs, $l);
		}
	}
close(LANG);

# Find languages with common character sets
@fivenine_langs = map { $_->{'lang'} }
		      grep { $_->{'charset'} eq 'iso-8859-2' } @langs;
@fifteen_langs = map { $_->{'lang'} }
		      grep { $_->{'charset'} eq 'iso-8859-15' } @langs;
@default_langs = map { $_->{'lang'} }
                      grep { $_->{'charset'} eq 'iso-8859-1' ||
			     $_->{'charset'} eq '' } @langs;

foreach $m (@modules) {
	# Translate the lang/* files
	if (-r "$m/lang/zh_TW.Big5") {
		system("iconv -f Big5 -t UTF-8 - <$m/lang/zh_TW.Big5 >$m/lang/zh_TW.UTF-8");
		}
	if (-r "$m/lang/zh_CN") {
		system("iconv -f GB2312 -t UTF-8 - <$m/lang/zh_CN >$m/lang/zh_CN.UTF-8");
		}
	if (-r "$m/lang/ja_JP.euc") {
		system("iconv -f EUC-JP -t UTF-8 - <$m/lang/ja_JP.euc >$m/lang/ja_JP.UTF-8");
		}
	if (-r "$m/lang/ko_KR.euc") {
		system("iconv -f EUC-KR -t UTF-8 - <$m/lang/ko_KR.euc >$m/lang/ko_KR.UTF-8");
		}
	if (-r "$m/lang/ru_SU") {
		system("iconv -f KOI8-R -t UTF-8 - <$m/lang/ru_SU >$m/lang/ru.UTF-8");
		}
	foreach $l (@fivenine_langs) {
		if (-r "$m/lang/$l") {
			system("iconv -f iso-8859-2 -t UTF-8 - <$m/lang/$l >$m/lang/$l.UTF-8");
			}
		}
	foreach $l (@fifteen_langs) {
		if (-r "$m/lang/$l") {
			system("iconv -f iso-8859-15 -t UTF-8 - <$m/lang/$l >$m/lang/$l.UTF-8");
			}
		}
	foreach $l (@default_langs) {
		if (-r "$m/lang/$l") {
			system("iconv -f iso-8859-1 -t UTF-8 - <$m/lang/$l >$m/lang/$l.UTF-8");
			}
		}

	# Translate the module.info file
	local %minfo;
	&read_file("$m/module.info", \%minfo);
	local %ominfo = %minfo;
	if ($minfo{'desc_zh_TW.Big5'}) {
		$minfo{'desc_zh_TW.UTF-8'} = &Big5ToUTF8($minfo{'desc_zh_TW.Big5'});
		}
	if ($minfo{'desc_zh_CN'}) {
		$minfo{'desc_zh_CN.UTF-8'} = &GB2312ToUTF8($minfo{'desc_zh_CN'});
		}
	if ($minfo{'desc_ja_JP.euc'}) {
		$minfo{'desc_ja_JP.UTF-8'} = &EUCToUTF8($minfo{'desc_ja_JP.euc'});
		}
	if ($minfo{'desc_ko_KR.euc'}) {
		$minfo{'desc_ko_KR.UTF-8'} = &KRToUTF8($minfo{'desc_ko_KR.euc'});
		}
	if ($minfo{'desc_ru_SU'}) {
		$minfo{'desc_ru.UTF-8'} = &KOI8ToUTF8($minfo{'desc_ru_SU'});
		}
	foreach $l (@fivenine_langs) {
		if ($minfo{'desc_'.$l}) {
			$minfo{'desc_'.$l.'.UTF-8'} =
				&ISO88592ToUTF8($minfo{'desc_'.$l});
			}
		}
	foreach $l (@fifteen_langs) {
		if ($minfo{'desc_'.$l}) {
			$minfo{'desc_'.$l.'.UTF-8'} =
				&ISO885915ToUTF8($minfo{'desc_'.$l});
			}
		}
	foreach $l (@default_langs) {
		if ($minfo{'desc_'.$l}) {
			$minfo{'desc_'.$l.'.UTF-8'} =
				&DefaultToUTF8($minfo{'desc_'.$l});
			}
		}
	&write_file_diff("$m/module.info", \%minfo);

	# Translate the config.info file
	local %cinfo;
	if (&read_file("$m/config.info.zh_TW.Big5", \%cinfo)) {
		local %ocinfo = %cinfo;
		foreach $k (keys %cinfo) {
			$cinfo{$k} = &Big5ToUTF8($cinfo{$k});
			}
		&write_file_diff("$m/config.info.zh_TW.UTF-8", \%cinfo);
		}
	%cinfo = ( );
	if (&read_file("$m/config.info.zh_CN", \%cinfo)) {
		local %ocinfo = %cinfo;
		foreach $k (keys %cinfo) {
			$cinfo{$k} = &GB2312ToUTF8($cinfo{$k});
			}
		&write_file_diff("$m/config.info.zh_CN.UTF-8", \%cinfo);
		}
	%cinfo = ( );
	if (&read_file("$m/config.info.ja_JP.euc", \%cinfo)) {
		local %ocinfo = %cinfo;
		foreach $k (keys %cinfo) {
			$cinfo{$k} = &EUCToUTF8($cinfo{$k});
			}
		&write_file_diff("$m/config.info.ja_JP.UTF-8", \%cinfo);
		}
	%cinfo = ( );
	if (&read_file("$m/config.info.ko_KR.euc", \%cinfo)) {
		local %ocinfo = %cinfo;
		foreach $k (keys %cinfo) {
			$cinfo{$k} = &KRToUTF8($cinfo{$k});
			}
		&write_file_diff("$m/config.info.ko_KR.UTF-8", \%cinfo);
		}
	%cinfo = ( );
	if (&read_file("$m/config.info.ru_SU", \%cinfo)) {
		local %ocinfo = %cinfo;
		foreach $k (keys %cinfo) {
			$cinfo{$k} = &KOI8ToUTF8($cinfo{$k});
			}
		&write_file_diff("$m/config.info.ru.UTF-8", \%cinfo);
		}
	foreach $l (@fivenine_langs) {
		%cinfo = ( );
		if (&read_file("$m/config.info.$l", \%cinfo)) {
			local %ocinfo = %cinfo;
			foreach $k (keys %cinfo) {
				$cinfo{$k} = &ISO88592ToUTF8($cinfo{$k});
				}
			&write_file_diff("$m/config.info.$l.UTF-8", \%cinfo);
			}
		}
	foreach $l (@fifteen_langs) {
		%cinfo = ( );
		if (&read_file("$m/config.info.$l", \%cinfo)) {
			local %ocinfo = %cinfo;
			foreach $k (keys %cinfo) {
				$cinfo{$k} = &ISO885915ToUTF8($cinfo{$k});
				}
			&write_file_diff("$m/config.info.$l.UTF-8", \%cinfo);
			}
		}
	foreach $l (@default_langs) {
		%cinfo = ( );
		if (&read_file("$m/config.info.$l", \%cinfo)) {
			local %ocinfo = %cinfo;
			foreach $k (keys %cinfo) {
				$cinfo{$k} = &DefaultToUTF8($cinfo{$k});
				}
			&write_file_diff("$m/config.info.$l.UTF-8", \%cinfo);
			}
		}

	# Translate any help files
	opendir(DIR, "$m/help");
	foreach $h (readdir(DIR)) {
		if ($h =~ /(\S+)\.zh_TW.Big5\.html$/) {
			open(IN, "$m/help/$h");
			open(OUT, ">$m/help/$1.zh_TW.UTF-8.html");
			while(<IN>) {
				print OUT &Big5ToUTF8($_);
				}
			close(OUT);
			close(IN);
			}
		elsif ($h =~ /(\S+)\.zh_CN\.html$/) {
			open(IN, "$m/help/$h");
			open(OUT, ">$m/help/$1.zh_CN.UTF-8.html");
			while(<IN>) {
				print OUT &GB2312ToUTF8($_);
				}
			close(OUT);
			close(IN);
			}
		elsif ($h =~ /(\S+)\.ja_JP\.euc\.html$/) {
			open(IN, "$m/help/$h");
			open(OUT, ">$m/help/$1.ja_JP.UTF-8.html");
			while(<IN>) {
				print OUT &EUCToUTF8($_);
				}
			close(OUT);
			close(IN);
			}
		elsif ($h =~ /(\S+)\.ko_KR\.euc\.html$/) {
			open(IN, "$m/help/$h");
			open(OUT, ">$m/help/$1.ko_KR.UTF-8.html");
			while(<IN>) {
				print OUT &KRToUTF8($_);
				}
			close(OUT);
			close(IN);
			}
		elsif ($h =~ /(\S+)\.ru_SU\.euc\.html$/) {
			open(IN, "$m/help/$h");
			open(OUT, ">$m/help/$1.ko_ru.UTF-8.html");
			while(<IN>) {
				print OUT &KOI8ToUTF8($_);
				}
			close(OUT);
			close(IN);
			}
		else {
			foreach $l (@fivenine_langs) {
				if ($h =~ /(\S+)\.$l\.html$/) {
					open(IN, "$m/help/$h");
					open(OUT, ">$m/help/$1.$l.UTF-8.html");
					while(<IN>) {
						print OUT &ISO88592ToUTF8($_);
						}
					close(OUT);
					close(IN);
					}
				}
			foreach $l (@fifteen_langs) {
				if ($h =~ /(\S+)\.$l\.html$/) {
					open(IN, "$m/help/$h");
					open(OUT, ">$m/help/$1.$l.UTF-8.html");
					while(<IN>) {
						print OUT &ISO885915ToUTF8($_);
						}
					close(OUT);
					close(IN);
					}
				}
			foreach $l (@default_langs) {
				if ($h =~ /(\S+)\.$l\.html$/) {
					open(IN, "$m/help/$h");
					open(OUT, ">$m/help/$1.$l.UTF-8.html");
					while(<IN>) {
						print OUT &DefaultToUTF8($_);
						}
					close(OUT);
					close(IN);
					}
				}
			}
		}
	closedir(DIR);
	}

sub Big5ToUTF8
{
local ($str) = @_;
local $temp = "/tmp/$$.big5";
open(TEMP, ">$temp");
print TEMP $str;
close(TEMP);
local $out = `iconv -f Big5 -t UTF-8 - <$temp`;
unlink($temp);
return $out;
}

sub GB2312ToUTF8
{
local ($str) = @_;
local $temp = "/tmp/$$.cn";
open(TEMP, ">$temp");
print TEMP $str;
close(TEMP);
local $out = `iconv -f GB2312 -t UTF-8 - <$temp`;
unlink($temp);
return $out;
}

sub EUCToUTF8
{
local ($str) = @_;
local $temp = "/tmp/$$.cn";
open(TEMP, ">$temp");
print TEMP $str;
close(TEMP);
local $out = `iconv -f EUC-JP -t UTF-8 - <$temp`;
unlink($temp);
return $out;
}

sub KRToUTF8
{
local ($str) = @_;
local $temp = "/tmp/$$.cn";
open(TEMP, ">$temp");
print TEMP $str;
close(TEMP);
local $out = `iconv -f EUC-KR -t UTF-8 - <$temp`;
unlink($temp);
return $out;
}

sub KOI8ToUTF8
{
local ($str) = @_;
local $temp = "/tmp/$$.cn";
open(TEMP, ">$temp");
print TEMP $str;
close(TEMP);
local $out = `iconv -f KOI8-R -t UTF-8 - <$temp`;
unlink($temp);
return $out;
}

sub ISO88592ToUTF8
{
local ($str) = @_;
local $temp = "/tmp/$$.cn";
open(TEMP, ">$temp");
print TEMP $str;
close(TEMP);
local $out = `iconv -f iso-8859-2 -t UTF-8 - <$temp`;
unlink($temp);
return $out;
}

sub ISO885915ToUTF8
{
local ($str) = @_;
local $temp = "/tmp/$$.cn";
open(TEMP, ">$temp");
print TEMP $str;
close(TEMP);
local $out = `iconv -f iso-8859-15 -t UTF-8 - <$temp`;
unlink($temp);
return $out;
}

sub DefaultToUTF8
{
local ($str) = @_;
local $temp = "/tmp/$$.cn";
open(TEMP, ">$temp");
print TEMP $str;
close(TEMP);
local $out = `iconv -f iso-8859-1 -t UTF-8 - <$temp`;
unlink($temp);
return $out;
}

# read_file(file, &assoc, [&order], [lowercase])
# Fill an associative array with name=value pairs from a file
sub read_file
{
open(ARFILE, $_[0]) || return 0;
while(<ARFILE>) {
	s/\r|\n//g;
        if (!/^#/ && /^([^=]+)=(.*)$/) {
		$_[1]->{$_[3] ? lc($1) : $1} = $2;
		push(@{$_[2]}, $1) if ($_[2]);
        	}
        }
close(ARFILE);
return 1;
}
 
# write_file_diff(file, array)
# Write out the contents of an associative array as name=value lines
sub write_file_diff
{
local(%old, @order);
&read_file($_[0], \%old, \@order);
return if (!&diff(\%old, $_[1]));
open(ARFILE, ">$_[0]");
foreach $k (@order) {
        print ARFILE $k,"=",$_[1]->{$k},"\n" if (exists($_[1]->{$k}));
	}
foreach $k (keys %{$_[1]}) {
        print ARFILE $k,"=",$_[1]->{$k},"\n" if (!exists($old{$k}));
        }
close(ARFILE);
}

sub diff
{
if (scalar(keys %{$_[0]}) != scalar(keys %{$_[1]})) {
	return 1;
	}
foreach $k (keys %{$_[0]}) {
	if ($_[0]->{$k} ne $_[1]->{$k}) {
		return 1;
		}
	}
return 0;
}
