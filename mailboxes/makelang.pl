#!/usr/local/bin/perl

@ARGV == 1 || die "usage: makelang.pl <language>";

$usermin = "/usr/local/useradmin/mailbox/ulang";
$mailboxes = "/usr/local/webadmin/mailboxes/lang";
$sendmail = "/usr/local/webadmin/sendmail/lang";

&read_file("$mailboxes/en", \%emailboxes, \@eorder);
&read_file("$sendmail/en", \%esendmail);
&read_file("$usermin/en", \%eusermin);

&read_file("$mailboxes/$ARGV[0]", \%fmailboxes);
&read_file("$sendmail/$ARGV[0]", \%fsendmail);
&read_file("$usermin/$ARGV[0]", \%fusermin);

foreach $k (@eorder) {
	if ($emailboxes{$k} eq $esendmail{$k} &&
	    $fsendmail{$k} &&
	    $fsendmail{$k} ne $esendmail{$k}) {
		print "$k=$fsendmail{$k}\n";
		}
	elsif ($emailboxes{$k} eq $eusermin{$k} &&
	       $fusermin{$k} &&
	       $fusermin{$k} ne $eusermin{$k}) {
		print "$k=$fusermin{$k}\n";
		}
	}

# read_file(file, &assoc, [&order], [lowercase])
# Fill an associative array with name=value pairs from a file
sub read_file
{
local $_;
open(ARFILE, "<".$_[0]) || return 0;
while(<ARFILE>) {
	chomp;
	local $hash = index($_, "#");
	local $eq = index($_, "=");
	if ($hash != 0 && $eq >= 0) {
		local $n = substr($_, 0, $eq);
		local $v = substr($_, $eq+1);
		$_[1]->{$_[3] ? lc($n) : $n} = $v;
		push(@{$_[2]}, $n) if ($_[2]);
        	}
        }
close(ARFILE);
if (defined($main::read_file_cache{$_[0]})) {
	%{$main::read_file_cache{$_[0]}} = %{$_[1]};
	}
return 1;
}


