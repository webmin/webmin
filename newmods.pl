# newmods.pl
# Updates an acl file to include new modules. Called with the parameters
# <config directory> <module>+

for($i=1; $i<@ARGV; $i++) {
	if (!(-d "$ARGV[0]/$ARGV[$i]")) {
		push(@new, $ARGV[$i]);
		}
	}

if (@new) {
	# Read in the existing file
	open(ACL, "$ARGV[0]/webmin.acl");
	@acl = <ACL>;
	close(ACL);

	# Get the list of users to grant new modules to
	if (open(NEWMODS, "$ARGV[0]/newmodules")) {
		while(<NEWMODS>) {
			s/\r|\n//g;
			$users{$_}++ if (/\S/);
			}
		close(NEWMODS);
		$newmods++;
		}

	if ($newmods) {
		# Find the users to add to
		for($i=0; $i<@acl; $i++) {
			if ($acl[$i] =~ /^(\S+):/ && $users{$1}) {
				push(@pos, $i);
				}
			}
		}
	else {
		# Just use 'root' or 'admin' or the first user in the file
		$pos[0] = 0;
		for($i=0; $i<@acl; $i++) {
			if ($acl[$i] =~ /^(\S+):/ &&
			    ($1 eq 'root' || $1 eq 'admin')) {
				$pos[0] = $i;
				last;
				}
			}
		}

	# Update it with new modules
	foreach $pos (@pos) {
		$acl[$pos] =~ /^(\S+):\s*(.*)$/ || next;
		$name = $1; @list = split(/\s+/, $2);
		foreach $o (@list) { $old{$o}++; }
		foreach $n (@new) {
			push(@list, $n) if (!$old{$n});
			}
		$acl[$pos] = "$name: ".join(" ",@list)."\n";
		}

	# Write it out
	open(ACL, ">$ARGV[0]/webmin.acl");
	print ACL @acl;
	close(ACL);
	}

