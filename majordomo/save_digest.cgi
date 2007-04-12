#!/usr/local/bin/perl
# save_digest.cgi
# Save digest options

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
&lock_file($list->{'config'});
$conf = &get_list_config($list->{'config'});

&save_opt($conf, $list->{'config'}, "digest_name");
&save_opt($conf, $list->{'config'}, "digest_maxdays", \&check_days);
&save_opt($conf, $list->{'config'}, "digest_maxlines", \&check_lines);
&save_opt($conf, $list->{'config'}, "digest_volume", \&check_volume);
&save_opt($conf, $list->{'config'}, "digest_issue", \&check_issue);

&flush_file_lines();
&unlock_file($list->{'config'});
&webmin_log("digest", undef, $in{'name'}, \%in);
&redirect("edit_list.cgi?name=$in{'name'}");

sub check_days
{
return $_[0] =~ /^\d+$/ ? undef : $text{'digest_edays'};
}

sub check_lines
{
return $_[0] =~ /^\d+$/ ? undef : $text{'digest_elines'};
}

sub check_volume
{
return $_[0] =~ /^\d+$/ ? undef : $text{'digest_evolume'};
}

sub check_issue
{
return $_[0] =~ /^\d+$/ ? undef : $text{'digest_eissue'};
}

