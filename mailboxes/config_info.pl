require './mailboxes-lib.pl';

sub show_userIgnoreList
{
  my($ig_usr) = shift(@_) || '';
  $ig_usr =~ s/\t/\n/g;
  my($preta)  = '<TEXTAREA NAME="ignore_users" COLS="35" ROWS="4">';
  my($postta) = '</TEXTAREA>';

  return
      $preta .
      $ig_usr .
      $postta .
      '&nbsp;' .
      &user_chooser_button("ignore_users", 1);
}

sub parse_userIgnoreList
{
  $in{'ignore_users'} =~ s/\r?\n/\t/g;
  return $main::in{'ignore_users'};
}
