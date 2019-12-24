#!/usr/local/bin/perl
# Creates UTF-8 encoded language files from their native encodings

@ARGV == 1 || die "Usage: $0 <directory>";
chdir($ARGV[0]) || die "Failed to chdir to $ARGV[0] : $!";
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
@fiveone_langs = map { $_->{'lang'} }
		       grep { $_->{'charset'} eq 'windows-1251' } @langs;
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
		system("iconv -c -f Big5 -t UTF-8 - <$m/lang/zh_TW.Big5 >$m/lang/zh_TW.UTF-8");
		}
	if (-r "$m/lang/zh_CN") {
		system("iconv -c -f GB2312 -t UTF-8 - <$m/lang/zh_CN >$m/lang/zh_CN.UTF-8");
		}
	if (-r "$m/lang/ja_JP.euc") {
		system("iconv -c -f EUC-JP -t UTF-8 - <$m/lang/ja_JP.euc >$m/lang/ja_JP.UTF-8");
		}
	if (-r "$m/lang/ko_KR.euc") {
		system("iconv -c -f EUC-KR -t UTF-8 - <$m/lang/ko_KR.euc >$m/lang/ko_KR.UTF-8");
		}
	if (-r "$m/lang/ru_SU") {
		system("iconv -c -f KOI8-R -t UTF-8 - <$m/lang/ru_SU >$m/lang/ru.UTF-8");
		}
	foreach $l (@fiveone_langs) {
		if (-r "$m/lang/$l") {
			system("iconv -c -f windows-1251 -t UTF-8 - <$m/lang/$l >$m/lang/$l.UTF-8");
			}
		}
	foreach $l (@fivenine_langs) {
		if (-r "$m/lang/$l") {
			system("iconv -c -f iso-8859-2 -t UTF-8 - <$m/lang/$l >$m/lang/$l.UTF-8");
			}
		}
	foreach $l (@fifteen_langs) {
		if (-r "$m/lang/$l") {
			system("iconv -c -f iso-8859-15 -t UTF-8 - <$m/lang/$l >$m/lang/$l.UTF-8");
			}
		}
	foreach $l (@default_langs) {
		if (-r "$m/lang/$l") {
			system("iconv -c -f iso-8859-1 -t UTF-8 - <$m/lang/$l >$m/lang/$l.UTF-8");
			}
		}
        # Translate the ulang/* files
	if (-r "$m/ulang/zh_TW.Big5") {
		system("iconv -c -f Big5 -t UTF-8 - <$m/ulang/zh_TW.Big5 >$m/ulang/zh_TW.UTF-8");
		}
	if (-r "$m/ulang/zh_CN") {
		system("iconv -c -f GB2312 -t UTF-8 - <$m/ulang/zh_CN >$m/ulang/zh_CN.UTF-8");
		}
	if (-r "$m/ulang/ja_JP.euc") {
		system("iconv -c -f EUC-JP -t UTF-8 - <$m/ulang/ja_JP.euc >$m/ulang/ja_JP.UTF-8");
		}
	if (-r "$m/ulang/ko_KR.euc") {
		system("iconv -c -f EUC-KR -t UTF-8 - <$m/ulang/ko_KR.euc >$m/ulang/ko_KR.UTF-8");
		}
	if (-r "$m/ulang/ru_SU") {
		system("iconv -c -f KOI8-R -t UTF-8 - <$m/ulang/ru_SU >$m/ulang/ru.UTF-8");
		}
	foreach $l (@fiveone_langs) {
		if (-r "$m/ulang/$l") {
			system("iconv -c -f windows-1251 -t UTF-8 - <$m/ulang/$l >$m/ulang/$l.UTF-8");
			}
		}
	foreach $l (@fivenine_langs) {
		if (-r "$m/ulang/$l") {
			system("iconv -c -f iso-8859-2 -t UTF-8 - <$m/ulang/$l >$m/ulang/$l.UTF-8");
			}
		}
	foreach $l (@fifteen_langs) {
		if (-r "$m/ulang/$l") {
			system("iconv -c -f iso-8859-15 -t UTF-8 - <$m/ulang/$l >$m/ulang/$l.UTF-8");
			}
		}
	foreach $l (@default_langs) {
		if (-r "$m/ulang/$l") {
			system("iconv -c -f iso-8859-1 -t UTF-8 - <$m/ulang/$l >$m/ulang/$l.UTF-8");
			}
		}
	# Translate the module.info.LANG files
	local %minfo;
	if (&read_file("$m/module.info.zh_TW.Big5", \%minfo)) {
		%tminfo = ( );
		foreach $k (keys %minfo) {
			($tk = $k) =~ s/zh_TW$/zh_TW.UTF-8/;
			$minfo{$tk} = &Big5ToUTF8($minfo{$k});
			}
		&write_file_diff("$m/module.info.zh_TW.UTF-8", \%tminfo);
		}
	%minfo = ( );
	if (&read_file("$m/module.info.zh_CN", \%minfo)) {
		%tminfo = ( );
		foreach $k (keys %minfo) {
			($tk = $k) =~ s/zh_CN$/zh_CN.UTF-8/;
			$minfo{$tk} = &GB2312ToUTF8($minfo{$k});
			}
		&write_file_diff("$m/module.info.zh_CN.UTF-8", \%tminfo);
		}
	%minfo = ( );
	if (&read_file("$m/module.info.ja_JP.euc", \%minfo)) {
		%tminfo = ( );
		foreach $k (keys %minfo) {
			($tk = $k) =~ s/ja_JP.euc$/ja_JP.UTF-8/;
			$tminfo{$tk} = &EUCToUTF8($minfo{$k});
			}
		&write_file_diff("$m/module.info.ja_JP.UTF-8", \%tminfo);
		}
	%minfo = ( );
	if (&read_file("$m/module.info.ko_KR.euc", \%minfo)) {
		%tminfo = ( );
		foreach $k (keys %minfo) {
			($tk = $k) =~ s/ko_KR.euc$/ko_KR.UTF-8/;
			$tminfo{$tk} = &KRToUTF8($minfo{$k});
			}
		&write_file_diff("$m/module.info.ko_KR.UTF-8", \%tminfo);
		}
	%minfo = ( );
	if (&read_file("$m/module.info.ru_SU", \%minfo)) {
		%tminfo = ( );
		foreach $k (keys %minfo) {
			($tk = $k) =~ s/ru_SU$/ru.UTF-8/;
			$tminfo{$tk} = &KOI8ToUTF8($minfo{$k});
			}
		&write_file_diff("$m/module.info.ru.UTF-8", \%tminfo);
		}
	foreach $l (@fiveone_langs) {
		%minfo = ( );
		if (&read_file("$m/module.info.$l", \%minfo)) {
			%tminfo = ( );
			foreach $k (keys %minfo) {
				($tk = $k) =~ s/$l$/$l.UTF-8/;
				$tminfo{$tk} = &Windows1251ToUTF8($minfo{$k});
				}
			&write_file_diff("$m/module.info.$l.UTF-8", \%tminfo);
			}
		}
	foreach $l (@fivenine_langs) {
		%minfo = ( );
		if (&read_file("$m/module.info.$l", \%minfo)) {
			%tminfo = ( );
			foreach $k (keys %minfo) {
				($tk = $k) =~ s/$l$/$l.UTF-8/;
				$tminfo{$tk} = &ISO88592ToUTF8($minfo{$k});
				}
			&write_file_diff("$m/module.info.$l.UTF-8", \%tminfo);
			}
		}
	foreach $l (@fifteen_langs) {
		%minfo = ( );
		if (&read_file("$m/module.info.$l", \%minfo)) {
			%tminfo = ( );
			foreach $k (keys %minfo) {
				($tk = $k) =~ s/$l$/$l.UTF-8/;
				$tminfo{$tk} = &ISO885915ToUTF8($minfo{$k});
				}
			&write_file_diff("$m/module.info.$l.UTF-8", \%tminfo);
			}
		}
	foreach $l (@default_langs) {
		%minfo = ( );
		if (&read_file("$m/module.info.$l", \%minfo)) {
			%tminfo = ( );
			foreach $k (keys %minfo) {
				($tk = $k) =~ s/$l$/$l.UTF-8/;
				$tminfo{$tk} = &DefaultToUTF8($minfo{$k});
				}
			&write_file_diff("$m/module.info.$l.UTF-8", \%tminfo);
			}
		}

	# Translate the config.info.LANG files
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
	foreach $l (@fiveone_langs) {
		%cinfo = ( );
		if (&read_file("$m/config.info.$l", \%cinfo)) {
			local %ocinfo = %cinfo;
			foreach $k (keys %cinfo) {
				$cinfo{$k} = &Windows1251ToUTF8($cinfo{$k});
				}
			&write_file_diff("$m/config.info.$l.UTF-8", \%cinfo);
			}
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
			foreach $l (@fiveone_langs) {
				if ($h =~ /(\S+)\.$l\.html$/) {
					open(IN, "$m/help/$h");
					open(OUT, ">$m/help/$1.$l.UTF-8.html");
					while(<IN>) {
						print OUT &Windows1251ToUTF8($_);
						}
					close(OUT);
					close(IN);
					}
				}
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
local $out = `iconv -c -f Big5 -t UTF-8 - <$temp`;
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
local $out = `iconv -c -f GB2312 -t UTF-8 - <$temp`;
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
local $out = `iconv -c -f EUC-JP -t UTF-8 - <$temp`;
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
local $out = `iconv -c -f EUC-KR -t UTF-8 - <$temp`;
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
local $out = `iconv -c -f KOI8-R -t UTF-8 - <$temp`;
unlink($temp);
return $out;
}

sub Windows1251ToUTF8
{
local ($str) = @_;
local $temp = "/tmp/$$.cn";
open(TEMP, ">$temp");
print TEMP $str;
close(TEMP);
local $out = `iconv -c -f windows-1251 -t UTF-8 - <$temp`;
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
local $out = `iconv -c -f iso-8859-2 -t UTF-8 - <$temp`;
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
local $out = `iconv -c -f iso-8859-15 -t UTF-8 - <$temp`;
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
local $out = `iconv -c -f iso-8859-1 -t UTF-8 - <$temp`;
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
