#!/usr/local/bin/perl
# Delete multiple rules

require './tcpwrappers-lib.pl';
&ReadParse();
&error_setup($text{'del_err'});

@d = split(/\0/, $in{'d'});
@d || &error($text{'del_enone'});
$file = $in{'allow'} ? $config{'hosts_allow'} : $config{'hosts_deny'};
@rules = &list_rules($file);

# Do the delete
&lock_file($file);

foreach $d (@d) {
    ($rule) = grep { $_->{'id'} == $d } @rules;
    $rule || &error($text{'edit_eid'});
    &delete_rule($file, $rule);
}

&unlock_file($file);
&webmin_log("delete", "rules", scalar(@d));

&redirect("");
