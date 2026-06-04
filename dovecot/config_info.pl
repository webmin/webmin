require 'dovecot-lib.pl';

# config_post_save(&newconfig, &oldconfig)
# Called after the module's configuration has been saved
sub config_post_save
{
my ($newconfig, $oldconfig) = @_;
my $f = $newconfig->{'add_config'};
$f =~ s/^\s+|\s+$//g;
if ($f && $f =~ /^\// && !-r $f && !-e $f && !-l $f) {
	&open_lock_tempfile(ADDCONF, ">$f");
	&close_tempfile(ADDCONF);
	}
}

1;
