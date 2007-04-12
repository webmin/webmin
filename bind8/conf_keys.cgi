#!/usr/local/bin/perl
# conf_keys.cgi
# Display options for other DNS servers

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'keys_ecannot'});
&ui_print_header(undef, $text{'keys_title'}, "");

$conf = &get_config();
@keys = ( &find("key", $conf), { } );

print "<form action=save_keys.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'keys_id'}</b></td> ",
      "<td><b>$text{'keys_alg'}</b></td> ",
      "<td><b>$text{'keys_secret'}</b></td> </tr>\n";
for($i=0; $i<@keys; $i++) {
	$k = $keys[$i];
	print "<tr $cb>\n";
	printf "<td><input name=id_$i size=15 value='%s'></td>\n",
		$k->{'value'};

	@algs = ( "hmac-md5" );
	$alg = &find_value("algorithm", $k->{'members'});
	print "<td><select name=alg_$i>\n";
	local $found;
	foreach $a (@algs) {
		printf "<option %s>%s\n", $alg eq $a ? "selected" : "", $a;
		$found++ if ($alg eq $a);
		}
	print "<option selected>$alg\n" if (!$found && $alg);
	print "</select></td>\n";

	printf "<td><input name=secret_$i size=64 value='%s'></td> </tr>\n",
		&find_value("secret", $k->{'members'});
	}
print "</table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

