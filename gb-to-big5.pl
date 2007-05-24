#!/usr/local/bin/perl
# Converts a module's zh_CN (simplified chinese) strings to zh_TW.Big5
# (traditional)

use Encode::HanConvert;

foreach $m (@ARGV) {
	# Convert lang file
	-d "$m/lang" || die "$m is not a module directory";
	local %zh;
	&read_file("$m/lang/zh_CN", \%zh);
	foreach $k (keys %zh) {
		$zh{$k} = gb_to_big5($zh{$k});
		}
	&write_file_diff("$m/lang/zh_TW.Big5", \%zh);
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
