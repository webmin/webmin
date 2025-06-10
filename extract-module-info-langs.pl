#!/usr/local/bin/perl
# For each given module.info file, create new module.info.XX files for each
# desc_XX= line in the original

if ($ARGV[0] eq "--dry-run") {
	$dryrun = 1;
	shift(@ARGV);
	}
@files = @ARGV;
@files || die "usage: $0 [--dry-run] [module.info]+";

foreach my $f (@files) {
	my %minfo;
	$f =~ /^(\S+)\/([^\/]+)$/ || die "$f is not a full path";
	my ($dir, $name) = ($1, $2);
	&read_file($f, \%minfo) || die "failed to read $f : $!";
	my @keys = keys %minfo;
	my %extract;
	foreach my $k (@keys) {
		if ($k =~ /^(desc|longdesc)_(\S+)/) {
			if (!$extract{$2}) {
				$extract{$2} ||= { };
				&read_file($f.".".$2, $extract{$2});
				}
			$extract{$2}->{$k} = $minfo{$k};
			delete($minfo{$k});
			}
		}
	if (%extract) {
		# Write out new and old files
		if ($dryrun) {
			print STDERR "$f : create separate files for ",
				     join(" ", sort(keys %extract)),"\n";
			}
		else {
			&write_file($f, \%minfo);
			system("cd $dir && git add $name");
			foreach my $l (keys %extract) {
				&write_file($f.".".$l, $extract{$l});
				system("cd $dir && git add $name.$l");
				}
			}
		}
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
 
# write_file(file, array)
# Write out the contents of an associative array as name=value lines
sub write_file
{
local(%old, @order);
&read_file($_[0], \%old, \@order);
open(ARFILE, ">$_[0]");
foreach $k (@order) {
        print ARFILE $k,"=",$_[1]->{$k},"\n" if (exists($_[1]->{$k}));
	}
foreach $k (keys %{$_[1]}) {
        print ARFILE $k,"=",$_[1]->{$k},"\n" if (!exists($old{$k}));
        }
close(ARFILE);
}


