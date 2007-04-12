
do 'majordomo-lib.pl';
$conf = &get_config();
@lists = &list_lists($conf);

# useradmin_create_user(&details)
# Add a user to the mailing list
sub useradmin_create_user
{
foreach $l (@lists) {
	if ($config{"sync_$l"}) {
		local $dom = $config{"shost_$l"};
		$dom = &get_system_hostname() if (!$dom);
		local $list = &get_list($l, $conf);
		local $pass = &find_value("admin_passwd",
			   &get_list_config($list->{'config'}));
		&lock_file($list->{'members'});
		open(WRAPPER, "|$config{'program_dir'}/wrapper majordomo");
		print WRAPPER "From: $_[0]->{'user'}\@$dom\n\n";
		print WRAPPER "approve $pass subscribe $l ",
			      "$_[0]->{'user'}\@$dom\n\n";
		close(WRAPPER);
		sleep(1);
		&unlock_file($list->{'members'});
		}
	}
}

# useradmin_delete_user(&details)
# Delete a user from the mailing list
sub useradmin_delete_user
{
foreach $l (@lists) {
	if ($config{"sync_$l"}) {
		local $dom = $config{"shost_$l"};
		$dom = &get_system_hostname() if (!$dom);
		local $list = &get_list($l, $conf);
		local $pass = &find_value("admin_passwd",
			   &get_list_config($list->{'config'}));
		&lock_file($list->{'members'});
		open(WRAPPER, "|$config{'program_dir'}/wrapper majordomo");
		print WRAPPER "From: $_[0]->{'user'}\@$dom\n\n";
		print WRAPPER "approve $pass unsubscribe $l ",
			      "$_[0]->{'user'}\@$dom\n\n";
		close(WRAPPER);
		sleep(1);
		&unlock_file($list->{'members'});
		}
	}
}

# useradmin_modify_user(&details)
# Does nothing
sub useradmin_modify_user
{
return if ($_[0]->{'user'} eq $_[0]->{'olduser'} || !$_[0]->{'olduser'});
foreach $l (@lists) {
	if ($config{"sync_$l"}) {
		# Directly update the subscription list, if the user is on it
		local $dom = $config{"shost_$l"};
		$dom = &get_system_hostname() if (!$dom);
		local $list = &get_list($l, $conf);
		&lock_file($list->{'members'});
		local $lref = &read_file_lines($list->{'members'});
		local ($i, $found);
		for($i=0; $i<@$lref; $i++) {
			if ($lref->[$i] eq "$_[0]->{'olduser'}\@$dom") {
				$lref->[$i] = "$_[0]->{'user'}\@$dom";
				$found++;
				}
			}
		&flush_file_lines() if ($found);
		&unlock_file($list->{'members'});
		}
	}

}

1;

