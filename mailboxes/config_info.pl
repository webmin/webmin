require './mailboxes-lib.pl';

sub show_userIgnoreList
{
  my($ig_usr) = shift(@_) || '';
  $ig_usr =~ s/\t/\n/g;
  my($preta)  = "<input name=\"ignore_users\" value=\"$ig_usr\" size=\"50\">";

  return
      $preta .
      '&nbsp;' .
      &user_chooser_button("ignore_users", 1);
}

sub parse_userIgnoreList
{
  $in{'ignore_users'} =~ s/\r?\n/\t/g;
  return $main::in{'ignore_users'};
}
