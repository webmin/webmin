
require 'acl-lib.pl';

# Rename the .acl files for any groups to .gacl files
sub module_install
{
# Fix up .acl files
local @mods = &get_all_module_infos();
local %isuser = map { $_->{'name'}, 1 } &list_users();
local $g;
foreach $g (&list_groups()) {
	next if ($isuser{$g->{'name'}});
	local $m;
	foreach $m (@mods) {
		if (-r "$config_directory/$m->{'dir'}/$g->{'name'}.acl") {
			print STDERR "renaming $config_directory/$m->{'dir'}/$g->{'name'}.acl $config_directory/$m->{'dir'}/$g->{'name'}.gacl\n";
			rename("$config_directory/$m->{'dir'}/$g->{'name'}.acl",
			       "$config_directory/$m->{'dir'}/$g->{'name'}.gacl");
			}
		}
	}

# Update sub-groups in webmin.groups file to use @ names
foreach $g (&list_groups()) {
	local ($u, @newmembers, $any);
	foreach $u (@{$g->{'members'}}) {
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
		print STDERR "Changing members of $g->{'name'} to ",join(" ", @newmembers),"\n";
		&modify_group($g->{'name'}, $g);
		}
	}
}

