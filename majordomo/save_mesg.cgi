#!/usr/local/bin/perl
# save_mesg.cgi
# Save message options

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
&lock_file($list->{'config'});
$conf = &get_list_config($list->{'config'});
&save_opt($conf, $list->{'config'}, "reply_to", \&check_reply);
&save_opt($conf, $list->{'config'}, "sender", \&check_sender);
&save_opt($conf, $list->{'config'}, "resend_host", \&check_host);
&save_opt($conf, $list->{'config'}, "subject_prefix");
&save_select($conf, $list->{'config'}, "precedence");
&save_choice($conf, $list->{'config'}, "purge_received");
&save_opt($conf, $list->{'config'}, "maxlength", \&check_maxlength);
&flush_file_lines();
&unlock_file($list->{'config'});
&webmin_log("mesg", undef, $in{'name'}, \%in);
&redirect("edit_list.cgi?name=$in{'name'}");

sub check_reply
{
return $_[0] =~ /^\S+$/ ? undef : $text{'mesg_ereply'};
}

sub check_sender
{
return $_[0] =~ /\@/ ? $text{'mesg_esender2'} :
       $_[0] =~ /^\S+$/ ? undef : $text{'mesg_esender'};
}

sub check_host
{
return $_[0] =~ /^[A-z0-9\-\.]+$/ ? undef : $text{'mesg_ehost'};
}

sub check_maxlength
{
return $_[0] =~ /^\d+$/ ? undef : $text{'mesg_emaxlength'};
}

