#!/usr/local/bin/perl
# conf_controls.cgi
# Display controls options

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'controls_ecannot'});
&ui_print_header(undef, $text{'controls_title'}, "");

&ReadParse();
$conf = &get_config();
$controls = &find("controls", $conf);
$mems = $controls->{'members'};

my ($inet, $unix, $addr, $port, $file, $perms, $owner, $group);
my @addrvals=();

foreach $mem ( @$mems ) {
  if ($mem->{'name'} eq "inet") {
    $inet=$mem;
    # Directive reads
    #  INET ( ip_addr | * ) PORT ip_port ALLOW address_match_list
    # the parser will see the address matchlist as a set of members
    # everything else is a value.
    my $v=$inet->{'values'};

    $addr=$v->[0];
    $port=$v->[2];

    foreach $addrmatch (@{$inet->{'members'}}) {
      push @addrvals, $addrmatch->{'name'};
    }
  } elsif ($mem->{'name'} eq "unix") {
    $unix=$mem;
    # Directive reads
    #  UNIX path_name PERM number OWNER number GROUP number;
    my $v=$unix->{'values'};

    $file=$v->[0];
    $perms=$v->[2];
    $owner=$v->[4];
    $group=$v->[6];
  }
}

$inetdefault=defined($inet)?"":" checked";
$inetset=defined($inet)?" checked":"";
$unixdefault=defined($unix)?"":" checked";
$unixset=defined($unix)?" checked":"";

print "<form action=save_controls.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'controls_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
print "<td valign=top><b>",
       $text{'controls_inet'},
      "</b></td>\n";
print "<td nowrap valign=top>\n";
print "<input type=radio name=inet_def value=1$inetdefault> ",
       $text{'default'},
      "\n";
print "<input type=radio name=inet_def value=0$inetset>\n";
print "<input name=inetaddr size=16 value=$addr></td>\n";
print "<td valign=top>",
       $text{'controls_port'},
      "</td>\n";
print "<td valign=top>",
      "<input name=inetport size=6 value=$port></td>\n";
print "<td valign=top>",
      $text{'controls_allow'},
      "</td>\n";
print "<td valign=top>",
      "<textarea name=inetallow rows=4 cols=40 wrap=auto>\n",
       join(" ", @addrvals),
      "</textarea>\n";
print "</td></tr>\n";
print "<tr>\n";
print "<td valign=top><b>",
       $text{'controls_unix'},
      "</b></td>\n";
print "<td nowrap valign=top>\n";
print "<input type=radio name=unix_def value=1$unixdefault> ",
       $text{'default'},
      "\n";
print "<input type=radio name=unix_def value=0$unixset>\n";
print "<input name=unixfile size=16 value=$file></td>\n";
print "<td valign=top>",
      $text{'controls_permissions'},
      "</td>\n";
print "<td valign=top>",
      "<input name=unixperms size=6 value=$perms></td>\n";
print "<td valign=top>",
      $text{'controls_owner'},
      "</td>\n";
print "<td valign=top>",
      "<input name=unixowner size=8 value=$owner>\n",
      $text{'controls_group'},
      "<input name=unixgroup size = 8 value=$group>\n";
print "</td></tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});


