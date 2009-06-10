
do 'apache-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_global.cgi') {
	# Global options page
	return $access{'global'}==1 ? 'type=0' : 'none';
	}
elsif ($cgi eq 'htaccess.cgi') {
	return $access{'global'} ? '' : 'none';
	}
elsif ($cgi eq 'edit_defines.cgi' || $cgi eq 'allmanual_form.cgi' ||
       $cgi eq 'edit_mods.cgi') {
	return $access{'global'}==1 ? '' : 'none';
	}
else {
	# Get first allowed virtual host
	my $conf = &get_config();
	my ($virt) = grep { &can_edit_virt($_) }
			  &find_directive_struct("VirtualHost", $conf);
	my $vidx = &indexof($virt, @$conf);
	if ($cgi eq 'virt_index.cgi') {
		return 'virt='.$vidx;
		}
	elsif ($cgi eq 'edit_virt.cgi') {
		return 'virt='.$vidx.'&type=0';
		}
	elsif ($cgi eq 'dir_index.cgi' || $cgi eq 'edit_dir.cgi') {
		# Get first directory
		my ($dir) = &find_directive_struct(
				"Directory", $virt->{'members'});
		return 'none' if (!$dir);
		my $rv = 'virt='.$vidx.'&idx='.$didx;
		if ($cgi eq 'edit_dir.cgi') {
			$rv .= '&type=0';
			}
		return $rv;
		}
	}
return undef;
}
