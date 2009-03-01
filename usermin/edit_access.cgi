#!/usr/local/bin/perl
# edit_access.cgi
# Display IP access control form

require './usermin-lib.pl';
$access{'access'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'access_title'}, "");
&get_usermin_miniserv_config(\%miniserv);

print $text{'access_desc'},"<p>\n";

print &ui_form_start("change_access.cgi", "post");
print &ui_table_start($text{'access_header'}, undef, 2, [ "width=30%" ]);

$access = $miniserv{"allow"} ? 1 : $miniserv{"deny"} ? 2 : 0;
print &ui_table_row($text{'access_ip'},
  &ui_radio("access", $access,
      [ [ 0, $text{'access_all'} ],
        [ 1, $text{'access_allow'} ],
        [ 2, $text{'access_deny'} ] ])."<br>\n".
  &ui_textarea("ip",
    $access == 1 ? join("\n", split(/\s+/, $miniserv{"allow"})) :
    $access == 2 ? join("\n", split(/\s+/, $miniserv{"deny"})) : "",
    6, 30));

print &ui_table_row($text{'access_always'},
  &ui_yesno_radio("alwaysresolve", int($miniserv{'alwaysresolve'})));

eval "use Authen::Libwrap qw(hosts_ctl STRING_UNKNOWN)";
if (!$@) {
  print &ui_table_row($text{'access_libwrap'},
    &ui_yesno_radio("libwrap", int($miniserv{'libwrap'})));
  }

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

