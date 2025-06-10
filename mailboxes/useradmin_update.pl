
do 'mailboxes-lib.pl';

# useradmin_create_user(&details)
# Create a new empty mail file
sub useradmin_create_user
{
if ($config{'sync_create'} && !&test_mail_system()) {
	local ($dir, $style, $mailbox, $maildir) = &get_mail_style();
	if ($dir && -d $dir) {
		# Create mail file like /var/mail/USERNAME
		local $mf = &mail_file_style($_[0]->{'user'}, $dir, $style);
		if (!-e $mf) {
			&create_mail_file($_[0], $mf);
			}
		}
	if ($mailbox && !-e "$_[0]->{'home'}/$mailbox") {
		# Create mail file ~USERNAME/Mailbox
		&create_mail_file($_[0], "$_[0]->{'home'}/$mailbox");
		}
	if ($maildir && !-e "$_[0]->{'home'}/$maildir") {
		# Create mail directory like ~USERNAME/Maildir
		&create_mail_dir($_[0], "$_[0]->{'home'}/$maildir");
		}
	}
}

# create_mail_file(&user, file)
sub create_mail_file
{
open(TOUCH, ">$_[1]");
close(TOUCH);
if ($config{'sync_perms'}) {
	system("chmod ".
	       quotemeta($config{'sync_perms'})." ".
	       quotemeta($_[1]));
	}
chown($_[0]->{'uid'}, $_[0]->{'gid'}, $_[1]);
}

# create_mail_dir(&user, dir)
sub create_mail_dir
{
local $d;
foreach $d ($_[1], "$_[0]/cur", "$_[1]/tmp", "$_[1]/new") {
	&make_dir($d, 0700);
	if ($config{'sync_perms'}) {
		system("chmod ".
		       quotemeta($config{'sync_perms'})." ".
		       quotemeta($d));
		}
	chown($_[0]->{'uid'}, $_[0]->{'gid'}, $d);
	}
}



# useradmin_delete_user(&details)
# Delete the user's mail file
sub useradmin_delete_user
{
if ($config{'sync_delete'} && !&test_mail_system()) {
	local ($dir, $style, $mailbox, $maildir) = &get_mail_style();
	if ($dir && -d $dir) {
		local $mf = &mail_file_style($_[0]->{'user'}, $dir, $style);
		unlink($mf);
		unlink($mf.".pop");
		}
	&delete_user_index_files($_[0]->{'user'});
	}
}

# useradmin_modify_user(&details, &old)
# Rename the user's mail file if necessary, and change it's UID
sub useradmin_modify_user
{
if ($config{'sync_modify'} && !&test_mail_system() &&
    ($_[0]->{'user'} ne $_[1]->{'user'} || $_[0]->{'uid'} != $_[1]->{'uid'})) {
	local ($dir, $style, $mailbox, $maildir) = &get_mail_style();
	if ($dir && -d $dir) {
		local $omf = &mail_file_style($_[0]->{'olduser'}, $dir, $style);
		local $nmf = &mail_file_style($_[0]->{'user'}, $dir, $style);
		local @st = stat($omf);
		if ($st[4] != $_[0]->{'uid'}) {
			chown($_[0]->{'uid'}, $st[5], $omf);
			}
		if ($omf ne $nmf && -e $omf) {
			&rename_logged($omf, $nmf);
			}
		}
	}
}

1;

