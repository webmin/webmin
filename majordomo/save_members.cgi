#!/usr/local/bin/perl
# save_members.cgi
# Store the members of some list

require './majordomo-lib.pl';
&ReadParseMime();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$access{'edit'} || &error($text{'members_eedit'});
$list = &get_list($in{'name'}, &get_config());
$conf = &get_list_config($list->{'config'});
$pass = &find_value("admin_passwd", $conf);
$wrapper_path = $config{'wrapper_path'} || "$config{'program_dir'}/wrapper";

# find the list owner's email address
$aliases_files = &get_aliases_file();
@aliases = &foreign_call($aliases_module, "list_aliases", $aliases_files);
foreach $a (@aliases) {
	if ($a->{'name'} eq "owner-$in{'name'}" ||
	    $a->{'name'} eq "$in{'name'}-owner") {
		$owner = $a->{'values'}->[0];
		}
	}

&lock_file($list->{'members'});
if ($in{'update'}) {
	# save the new list of members
	$in{'members'} =~ s/\r//g;
	$in{'members'} =~ s/\n*$/\n/;
	&open_tempfile(MEMS, ">$list->{'members'}");
	&print_tempfile(MEMS, $in{'members'});
	&close_tempfile(MEMS);
	&unlock_file($list->{'members'});
	&webmin_log("members", undef, $in{'name'});
	}
elsif ($in{'add'}) {
	# call send_mail to subscribe an address
	$pass || &error($text{'members_esub'});
	$in{'addr_a'} =~ /^(\S+)\@(\S+)\.(\S+)$/ ||
		&error($text{'members_esubaddr'});
	$mail=sprintf("From: %s\nTo: %s\nSubject: subcribe\n\n",
		$owner ? $owner : $in{'addr_a'}, "majordomo");
	$mail .= "approve $pass subscribe $in{'name'} $in{'addr_a'}\n\n";
	&send_mail($mail);
	&unlock_file($list->{'members'});
	&webmin_log("subscribe", undef, $in{'name'},
		    { 'addr' => $in{'addr_a'} });
	}
elsif ($in{'remove'}) {
	# call send_mail to unsubscribe an address
	$pass || &error($text{'members_eunsub'});
	$in{'addr_r'} =~ /^(\S+)\@(\S+)\.(\S+)$/ ||
		&error($text{'members_eunsubaddr'});
        $mail=sprintf("From: %s\nTo: %s\nSubject: unsubcribe\n\n",
                $owner ? $owner : $in{'addr_a'}, "majordomo");
        $mail .= "approve $pass unsubscribe $in{'name'} $in{'addr_r'}\n\n";
        &send_mail($mail);
	&unlock_file($list->{'members'});
	&webmin_log("unsubscribe", undef, $in{'name'},
		    { 'addr' => $in{'addr_r'} });
	}
&redirect("edit_list.cgi?name=$in{'name'}");

sub send_mail
   {
   local $sent,$mail=$_[0];
   if (!$sent) {
        # Try to send the email by calling sendmail -t
        %sconfig = &foreign_config("sendmail");
        $sendmail = $sconfig{'sendmail_path'} ? $sconfig{'sendmail_path'}
                                              : &has_command("sendmail");
        if (-x $sendmail && open(MAIL, "| $sendmail -t")) {
                print MAIL $mail;
                if (close(MAIL)) {
                        $sent = 2;
                        }
                }
        }

   if (!$sent) {
	&error($text{'global_esendmail'}, "");
	}
   }
