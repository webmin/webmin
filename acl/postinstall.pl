
use strict;
use warnings;
require 'acl-lib.pl';
our ($config_directory);

# Rename the .acl files for any groups to .gacl files
sub module_install
{
# Fix up .acl files
my @mods = &get_all_module_infos();
my %isuser = map { $_->{'name'}, 1 } &list_users();
foreach my $g (&list_groups()) {
	next if ($isuser{$g->{'name'}});
	next if ($g->{'proto'});
	foreach my $m (@mods) {
		if (-r "$config_directory/$m->{'dir'}/$g->{'name'}.acl") {
			rename("$config_directory/$m->{'dir'}/$g->{'name'}.acl",
			     "$config_directory/$m->{'dir'}/$g->{'name'}.gacl");
			}
		}
	}

# Update sub-groups in webmin.groups file to use @ names
foreach my $g (&list_groups()) {
	my (@newmembers, $any);
	foreach my $u (@{$g->{'members'}}) {
		if ($u !~ /^\@/ && !$isuser{$u}) {
			push(@newmembers, '@'.$u);
			$any = 1;
			}
		else {
			push(@newmembers, $u);
			}
		}
	$g->{'members'} = \@newmembers;
	if ($any) {
		&modify_group($g->{'name'}, $g);
		}
	}
}

