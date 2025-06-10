
do 'apache-lib.pl';
do 'auth-lib.pl';

foreach $k (keys %config) {
	if ($k =~ /^sync_(.*)$/) {
		push(@sync, [ $1, $config{$k} ]);
		}
	}

# useradmin_create_user(&details)
sub useradmin_create_user
{
foreach $s (@sync) {
	if ($s->[1] =~ /create/ && !&get_authuser($s->[0], $_[0]->{'user'})) {
		&lock_file($s->[0]);
		&create_authuser($s->[0], { 'user' => $_[0]->{'user'},
					    'pass' => $_[0]->{'pass'} });
		&unlock_file($s->[0]);
		}
	}
}

# useradmin_delete_user(&details)
sub useradmin_delete_user
{
foreach $s (@sync) {
	if ($s->[1] =~ /delete/) {
		&lock_file($s->[0]);
		&delete_authuser($s->[0], $_[0]->{'user'});
		&unlock_file($s->[0]);
		}
	}
}

# useradmin_modify_user(&details)
sub useradmin_modify_user
{
foreach $s (@sync) {
	if ($s->[1] =~ /modify/) {
		&lock_file($s->[0]);
		&save_authuser($s->[0], $_[0]->{'olduser'},
			       { 'user' => $_[0]->{'user'},
				 'pass' => $_[0]->{'pass'} });
		&unlock_file($s->[0]);
		}
	}
}

1;

