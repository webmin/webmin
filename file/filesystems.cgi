#!/usr/local/bin/perl
# filesystems.cgi
# List all filesystems and their types

$trust_unknown_referers = 1;
require './file-lib.pl';
print "Content-type: text/plain\n\n";
if (!&foreign_check("mount") || !$access{'filesystems'}) {
	print "0\n";
	exit;
	}
&foreign_require("mount", "mount-lib.pl");
@mtab = &mount::list_mounted();
%mtab = map { $_->[0], $_ } @mtab;
@fstab = &mount::list_mounts();
%fstab = map { $_->[0], $_ } @fstab;
@mounts = ( @fstab, grep { !$fstab{$_->[0]} } @mtab );

print "1\n";
foreach $m (sort { length($a->[0]) <=> length($b->[0]) } @mounts) {
	next if ($m->[0] !~ /^\//);
	local @supp = @{$support{$m->[2]}};
	if (!@supp) {
		# Work out what this filesystem supports
		@supp = ( eval $config{$m->[2]."_acl"} ? 1 : 0,
			  eval $config{$m->[2]."_attr"} ? 1 : 0,
			  eval $config{$m->[2]."_ext"} ? 1 : 0 );
		$support{$m->[2]} = \@supp;
		}

	# Check if the filesystem really does support attrs and ACLs
	local @supp2 = @supp;
	if ($mtab{$m->[0]}) {
		if ($supp2[0]) {
			local $out = `$config{'getfacl'} '$m->[0]' 2>/dev/null`;
			if ($?) {
				$supp2[0] = 0;
				}
			else {
				local $aclcount;
				foreach $l (split(/\n/, $out)) {
					$l =~ s/#.*$//;
					$l =~ s/\s+$//;
					$aclcount++ if ($l =~ /\S/);
					}
				$supp2[0] = 0 if (!$aclcount);
				}
			}
		if ($supp2[1]) {
			local $out = `attr -l '$m->[0]' 2>/dev/null`;
			if ($?) {
				$supp2[1] = 0;
				}
			}
		}

	$m->[1] =~ s/\\/\//g;
	$chrooted = &make_chroot($m->[0]);
	if ($chrooted) {
		print join(" ", $chrooted, @$m[1..3], @supp2,
				$mtab{$m->[0]} ? 1 : 0,
				$fstab{$m->[0]} ? 1 : 0),"\n";
		}
	}

