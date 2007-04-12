#!/usr/local/bin/perl
# conf_servers.cgi
# Display options for other DNS servers

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'servers_ecannot'});
&ui_print_header(undef, $text{'servers_title'}, "");

$conf = &get_config();
@servers = ( &find("server", $conf), { } );
@keys = &find("key", $conf);

print "<form action=save_servers.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'servers_ip'}</b></td> ",
      "<td><b>$text{'servers_bogus'}</b></td> ",
      "<td><b>$text{'servers_format'}</b></td> ",
      "<td><b>$text{'servers_trans'}</b></td> ",
      (@keys ? "<td><b>$text{'servers_keys'}</b></td> " : ""), "</tr>\n";
for($i=0; $i<@servers; $i++) {
	$s = $servers[$i];
	print "<tr $cb>\n";
	printf "<td><input name=ip_$i size=15 value='%s'></td>\n",
		$s->{'value'};

	$bogus = &find_value("bogus", $s->{'members'});
	printf "<td><input type=radio name=bogus_$i value=yes %s> %s\n",
		lc($bogus) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=bogus_$i value='' %s> %s</td>\n",
		lc($bogus) eq 'yes' ? "" : "checked", $text{'no'};

	$format = &find_value("transfer-format", $s->{'members'});
	printf "<td><input type=radio name=format_$i value=one-answer %s> %s\n",
		lc($format) eq 'one-answer' ? "checked" : "",
		$text{'servers_one'};
	printf "<input type=radio name=format_$i value=many-answers %s> %s\n",
		lc($format) eq 'many-answers' ? "checked" : "",
		$text{'servers_many'};
	printf "<input type=radio name=format_$i value='' %s> %s</td>\n",
		$format ? "" : "checked", $text{'default'};

	printf "<td><input name=trans_$i size=8 value='%s'></td>\n",
		&find_value("transfers", $s->{'members'});

	if (@keys) {
		local %haskey;
		$keys = &find("keys", $s->{'members'});
		foreach $k (@{$keys->{'members'}}) {
			$haskey{$k->{'name'}}++;
			}
		print "<td>\n";
		foreach $k (@keys) {
			local $v = $k->{'value'};
			printf
			"<input type=checkbox name=keys_$i value='%s' %s> %s\n",
				$v, $haskey{$v} ? "checked" : "", $v;
			}
		print "</td>\n";
		}
	print "</tr>\n";
	}
print "</table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

